package database_test

import (
	"context"
	"errors"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/43374166/family-genealogy/server/internal/database"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// These tests require a disposable PostgreSQL database with migrations applied.
// CI runs:
//
//	go run ./cmd/migrate up
//	go test -race ./...
func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL is not set; skip PostgreSQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	pool, err := database.Open(ctx, dsn, 4)
	if err != nil {
		t.Fatalf("open test database: %v", err)
	}
	t.Cleanup(pool.Close)
	return pool
}

func TestTenantIsolationRejectsCrossFamilyParent(t *testing.T) {
	pool := testPool(t)
	familyA := insertFamily(t, pool, "A")
	familyB := insertFamily(t, pool, "B")
	parentB := insertPerson(t, pool, familyB, "父")
	childA := insertPerson(t, pool, familyA, "子")

	_, err := pool.Exec(context.Background(), `
		INSERT INTO parent_child_relationships (family_id, parent_id, child_id, parent_role)
		VALUES ($1::uuid, $2::uuid, $3::uuid, 'parent')`,
		familyA, parentB, childA,
	)
	requireSQLState(t, err, "23503")
}

func TestParentCannotBeOwnChild(t *testing.T) {
	pool := testPool(t)
	family := insertFamily(t, pool, "自环")
	person := insertPerson(t, pool, family, "人")

	_, err := pool.Exec(context.Background(), `
		INSERT INTO parent_child_relationships (family_id, parent_id, child_id, parent_role)
		VALUES ($1::uuid, $2::uuid, $2::uuid, 'parent')`,
		family, person,
	)
	requireSQLState(t, err, "23514")
}

func TestParentChildCycleIsRejected(t *testing.T) {
	pool := testPool(t)
	family := insertFamily(t, pool, "环路")
	a := insertPerson(t, pool, family, "甲")
	b := insertPerson(t, pool, family, "乙")
	c := insertPerson(t, pool, family, "丙")

	insertParentChild(t, pool, family, a, b)
	insertParentChild(t, pool, family, b, c)

	_, err := pool.Exec(context.Background(), `
		INSERT INTO parent_child_relationships (family_id, parent_id, child_id, parent_role)
		VALUES ($1::uuid, $2::uuid, $3::uuid, 'parent')`,
		family, c, a,
	)
	requireSQLState(t, err, "23514")
}

func TestPartialDateRequiresLargerUnit(t *testing.T) {
	pool := testPool(t)
	family := insertFamily(t, pool, "日期")

	_, err := pool.Exec(context.Background(), `
		INSERT INTO persons (family_id, surname, given_name, generation_no, birth_month)
		VALUES ($1::uuid, '张', '日期异常', 1, 6)`,
		family,
	)
	requireSQLState(t, err, "23514")
}

func TestSpousePairIsCanonical(t *testing.T) {
	pool := testPool(t)
	family := insertFamily(t, pool, "婚姻")
	p1 := insertPerson(t, pool, family, "甲")
	p2 := insertPerson(t, pool, family, "乙")

	var a, b string
	if err := pool.QueryRow(context.Background(),
		`SELECT LEAST($1::uuid, $2::uuid)::text, GREATEST($1::uuid, $2::uuid)::text`,
		p1, p2,
	).Scan(&a, &b); err != nil {
		t.Fatalf("order spouse ids: %v", err)
	}

	_, err := pool.Exec(context.Background(), `
		INSERT INTO spouse_relationships (family_id, person_a_id, person_b_id)
		VALUES ($1::uuid, $2::uuid, $3::uuid)`,
		family, b, a,
	)
	requireSQLState(t, err, "23514")
}

func TestFamilyHasOnlyOneActiveOwner(t *testing.T) {
	pool := testPool(t)
	family := insertFamily(t, pool, "所有权")
	u1 := insertUser(t, pool)
	u2 := insertUser(t, pool)
	insertMembership(t, pool, family, u1, "owner")
	_, err := pool.Exec(context.Background(), `
		INSERT INTO family_memberships (family_id, user_id, role)
		VALUES ($1::uuid, $2::uuid, 'owner')`,
		family, u2,
	)
	requireSQLState(t, err, "23505")
}

func TestAuditLogIsAppendOnly(t *testing.T) {
	pool := testPool(t)
	family := insertFamily(t, pool, "审计")

	var id int64
	if err := pool.QueryRow(context.Background(), `
		INSERT INTO audit_logs (family_id, action, entity_type)
		VALUES ($1::uuid, 'test', 'family')
		RETURNING id`,
		family,
	).Scan(&id); err != nil {
		t.Fatalf("insert audit log: %v", err)
	}

	_, err := pool.Exec(context.Background(),
		`UPDATE audit_logs SET action = 'tampered' WHERE id = $1`, id)
	requireSQLState(t, err, "55000")
}

func insertFamily(t *testing.T, pool *pgxpool.Pool, suffix string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(), `
		INSERT INTO families (name, surname) VALUES ($1, '张') RETURNING id::text`,
		"测试家族-"+suffix+"-"+fmt.Sprint(time.Now().UnixNano()),
	).Scan(&id); err != nil {
		t.Fatalf("insert family: %v", err)
	}
	return id
}

func insertUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	var id string
	login := fmt.Sprintf("schema-test-%d@example.com", time.Now().UnixNano())
	if err := pool.QueryRow(context.Background(), `
		INSERT INTO users (login_name, password_hash, display_name)
		VALUES ($1, '$argon2id$v=19$m=65536,t=3,p=2$test$test', '测试用户')
		RETURNING id::text`, login,
	).Scan(&id); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	return id
}

func insertMembership(t *testing.T, pool *pgxpool.Pool, familyID, userID, role string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(), `
		INSERT INTO family_memberships (family_id, user_id, role)
		VALUES ($1::uuid, $2::uuid, $3) RETURNING id::text`,
		familyID, userID, role,
	).Scan(&id); err != nil {
		t.Fatalf("insert membership: %v", err)
	}
	return id
}

func insertPerson(t *testing.T, pool *pgxpool.Pool, familyID, givenName string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(), `
		INSERT INTO persons (family_id, surname, given_name, generation_no)
		VALUES ($1::uuid, '张', $2, 1) RETURNING id::text`,
		familyID, givenName,
	).Scan(&id); err != nil {
		t.Fatalf("insert person: %v", err)
	}
	return id
}

func insertParentChild(t *testing.T, pool *pgxpool.Pool, familyID, parentID, childID string) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), `
		INSERT INTO parent_child_relationships (family_id, parent_id, child_id, parent_role)
		VALUES ($1::uuid, $2::uuid, $3::uuid, 'parent')`,
		familyID, parentID, childID,
	); err != nil {
		t.Fatalf("insert parent-child: %v", err)
	}
}

func requireSQLState(t *testing.T, err error, want string) {
	t.Helper()
	if err == nil {
		t.Fatalf("expected SQLSTATE %s, got nil error", want)
	}
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		t.Fatalf("expected PostgreSQL error with SQLSTATE %s, got %T: %v", want, err, err)
	}
	if pgErr.Code != want {
		t.Fatalf("SQLSTATE = %s, want %s (%v)", pgErr.Code, want, err)
	}
}
