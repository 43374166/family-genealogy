package database_test

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/43374166/family-genealogy/server/internal/database"
	"github.com/go-sql-driver/mysql"
	"github.com/google/uuid"
)

// These tests require a disposable MySQL 8.4 database with migrations applied.
// CI runs:
//
//	go run ./cmd/migrate up
//	go test -race ./...
func testDB(t *testing.T) *database.DB {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_DSN")
	if dsn == "" {
		t.Skip("TEST_DATABASE_DSN is not set; skip MySQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	db, err := database.Open(ctx, dsn, 4)
	if err != nil {
		t.Fatalf("open test database: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	return db
}

func TestTenantIsolationRejectsCrossFamilyParent(t *testing.T) {
	db := testDB(t)
	familyA := insertFamily(t, db)
	familyB := insertFamily(t, db)
	parentB := insertPerson(t, db, familyB, "父")
	childA := insertPerson(t, db, familyA, "子")

	_, err := db.ExecContext(context.Background(), `
		INSERT INTO parent_child_relationships (id, family_id, parent_id, child_id, parent_role)
		VALUES (?, ?, ?, ?, 'parent')`,
		uuid.NewString(), familyA, parentB, childA,
	)
	requireErrorNumber(t, err, 1452)
}

func TestParentCannotBeOwnChild(t *testing.T) {
	db := testDB(t)
	family := insertFamily(t, db)
	person := insertPerson(t, db, family, "人")

	_, err := db.ExecContext(context.Background(), `
		INSERT INTO parent_child_relationships (id, family_id, parent_id, child_id, parent_role)
		VALUES (?, ?, ?, ?, 'parent')`,
		uuid.NewString(), family, person, person,
	)
	requireAnyErrorNumber(t, err, 3819, 1644)
}

func TestParentChildCycleIsRejected(t *testing.T) {
	db := testDB(t)
	family := insertFamily(t, db)
	a := insertPerson(t, db, family, "甲")
	b := insertPerson(t, db, family, "乙")
	c := insertPerson(t, db, family, "丙")

	insertParentChild(t, db, family, a, b)
	insertParentChild(t, db, family, b, c)

	_, err := db.ExecContext(context.Background(), `
		INSERT INTO parent_child_relationships (id, family_id, parent_id, child_id, parent_role)
		VALUES (?, ?, ?, ?, 'parent')`,
		uuid.NewString(), family, c, a,
	)
	requireErrorNumber(t, err, 1644)
}

func TestPartialDateRequiresLargerUnit(t *testing.T) {
	db := testDB(t)
	family := insertFamily(t, db)

	_, err := db.ExecContext(context.Background(), `
		INSERT INTO persons (id, family_id, surname, given_name, generation_no, birth_month)
		VALUES (?, ?, '张', '日期异常', 1, 6)`,
		uuid.NewString(), family,
	)
	requireErrorNumber(t, err, 3819)
}

func TestSpousePairIsCanonical(t *testing.T) {
	db := testDB(t)
	family := insertFamily(t, db)
	p1 := insertPerson(t, db, family, "甲")
	p2 := insertPerson(t, db, family, "乙")
	a, b := p1, p2
	if a > b {
		a, b = b, a
	}

	_, err := db.ExecContext(context.Background(), `
		INSERT INTO spouse_relationships (id, family_id, person_a_id, person_b_id)
		VALUES (?, ?, ?, ?)`,
		uuid.NewString(), family, b, a,
	)
	requireErrorNumber(t, err, 3819)
}

func TestFamilyHasOnlyOneActiveOwner(t *testing.T) {
	db := testDB(t)
	family := insertFamily(t, db)
	u1 := insertUser(t, db)
	u2 := insertUser(t, db)
	insertMembership(t, db, family, u1, "owner")

	_, err := db.ExecContext(context.Background(), `
		INSERT INTO family_memberships (id, family_id, user_id, role)
		VALUES (?, ?, ?, 'owner')`,
		uuid.NewString(), family, u2,
	)
	requireErrorNumber(t, err, 1062)
}

func TestAuditLogIsAppendOnly(t *testing.T) {
	db := testDB(t)
	family := insertFamily(t, db)

	var id int64
	result, err := db.ExecContext(context.Background(), `
		INSERT INTO audit_logs (family_id, action, entity_type)
		VALUES (?, 'test', 'family')`,
		family,
	)
	if err != nil {
		t.Fatalf("insert audit log: %v", err)
	}
	id, err = result.LastInsertId()
	if err != nil {
		t.Fatalf("read audit id: %v", err)
	}

	_, err = db.ExecContext(context.Background(),
		`UPDATE audit_logs SET action = 'tampered' WHERE id = ?`, id)
	requireErrorNumber(t, err, 1644)

	_, err = db.ExecContext(context.Background(),
		`DELETE FROM audit_logs WHERE id = ?`, id)
	requireErrorNumber(t, err, 1644)
}

func TestGeneratedFullName(t *testing.T) {
	db := testDB(t)
	family := insertFamily(t, db)
	person := insertPerson(t, db, family, "明远")

	var fullName string
	if err := db.QueryRowContext(context.Background(),
		`SELECT full_name FROM persons WHERE id = ?`, person).Scan(&fullName); err != nil {
		t.Fatalf("read generated full_name: %v", err)
	}
	if fullName != "张明远" {
		t.Fatalf("full_name = %q, want 张明远", fullName)
	}
}

func insertFamily(t *testing.T, db *database.DB) string {
	t.Helper()
	id := uuid.NewString()
	if _, err := db.ExecContext(context.Background(), `
		INSERT INTO families (id, name, surname) VALUES (?, ?, '张')`,
		id, "测试家族-"+id,
	); err != nil {
		t.Fatalf("insert family: %v", err)
	}
	return id
}

func insertUser(t *testing.T, db *database.DB) string {
	t.Helper()
	id := uuid.NewString()
	if _, err := db.ExecContext(context.Background(), `
		INSERT INTO users (id, login_name, password_hash, display_name)
		VALUES (?, ?, '$argon2id$v=19$m=65536,t=3,p=2$test$test', '测试用户')`,
		id, "schema-test-"+id+"@example.com",
	); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	return id
}

func insertMembership(t *testing.T, db *database.DB, familyID, userID, role string) string {
	t.Helper()
	id := uuid.NewString()
	if _, err := db.ExecContext(context.Background(), `
		INSERT INTO family_memberships (id, family_id, user_id, role)
		VALUES (?, ?, ?, ?)`,
		id, familyID, userID, role,
	); err != nil {
		t.Fatalf("insert membership: %v", err)
	}
	return id
}

func insertPerson(t *testing.T, db *database.DB, familyID, givenName string) string {
	t.Helper()
	id := uuid.NewString()
	if _, err := db.ExecContext(context.Background(), `
		INSERT INTO persons (id, family_id, surname, given_name, generation_no)
		VALUES (?, ?, '张', ?, 1)`,
		id, familyID, givenName,
	); err != nil {
		t.Fatalf("insert person: %v", err)
	}
	return id
}

func insertParentChild(t *testing.T, db *database.DB, familyID, parentID, childID string) {
	t.Helper()
	if _, err := db.ExecContext(context.Background(), `
		INSERT INTO parent_child_relationships (id, family_id, parent_id, child_id, parent_role)
		VALUES (?, ?, ?, ?, 'parent')`,
		uuid.NewString(), familyID, parentID, childID,
	); err != nil {
		t.Fatalf("insert parent-child: %v", err)
	}
}

func requireErrorNumber(t *testing.T, err error, want uint16) {
	t.Helper()
	if err == nil {
		t.Fatalf("expected MySQL error %d, got nil", want)
	}
	var mysqlErr *mysql.MySQLError
	if !errors.As(err, &mysqlErr) {
		t.Fatalf("expected *mysql.MySQLError, got %T: %v", err, err)
	}
	if mysqlErr.Number != want {
		t.Fatalf("MySQL error number = %d, want %d (%v)", mysqlErr.Number, want, err)
	}
}

func requireAnyErrorNumber(t *testing.T, err error, wants ...uint16) {
	t.Helper()
	if err == nil {
		t.Fatalf("expected one of MySQL errors %v, got nil", wants)
	}
	var mysqlErr *mysql.MySQLError
	if !errors.As(err, &mysqlErr) {
		t.Fatalf("expected *mysql.MySQLError, got %T: %v", err, err)
	}
	for _, want := range wants {
		if mysqlErr.Number == want {
			return
		}
	}
	t.Fatalf("MySQL error number = %d, want one of %v (%v)", mysqlErr.Number, wants, err)
}
