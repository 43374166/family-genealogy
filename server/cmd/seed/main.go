package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/43374166/family-genealogy/server/internal/auth"
	"github.com/43374166/family-genealogy/server/internal/database"
)

const (
	demoFamilyID  = "10000000-0000-4000-8000-000000000001"
	demoUserID    = "20000000-0000-4000-8000-000000000001"
	demoMemberID  = "30000000-0000-4000-8000-000000000001"
	ownerPersonID = "50000000-0000-4000-8000-000000000116"
)

type branchSeed struct {
	ID       string
	ParentID string
	Name     string
	Sort     int
}

type personSeed struct {
	ID         string
	BranchID   string
	Surname    string
	GivenName  string
	Gender     string
	Generation int
	BirthOrder int
	BirthYear  int
	LifeStatus string
	Biography  string
}

type edgeSeed struct {
	ParentID string
	ChildID  string
	Role     string
}

func main() {
	dsn := os.Getenv("DATABASE_DSN")
	if dsn == "" {
		log.Fatal("DATABASE_DSN is required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	db, err := database.Open(ctx, dsn, 2)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer db.Close()

	var existing int
	if err := db.QueryRowContext(ctx, `SELECT COUNT(*) FROM families WHERE id = ?`, demoFamilyID).Scan(&existing); err != nil {
		log.Fatalf("check demo family: %v", err)
	}
	if existing > 0 {
		fmt.Println("demo data already present; nothing to do")
		return
	}

	passwordHash, err := auth.HashPassword("Demo#2026")
	if err != nil {
		log.Fatalf("hash demo password: %v", err)
	}

	tx, err := db.BeginTx(ctx, &sql.TxOptions{})
	if err != nil {
		log.Fatalf("begin seed transaction: %v", err)
	}
	defer func() { _ = tx.Rollback() }()

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO families (id, name, surname, motto, region, description)
		VALUES (?, '凌氏家族', '凌', '寻根溯源 · 传承家风', '',
		        '凌氏家族族谱，成员与分支由族长维护。')`,
		demoFamilyID,
	); err != nil {
		log.Fatalf("insert family: %v", err)
	}

	branches := []branchSeed{
		{"40000000-0000-4000-8000-000000000001", "", "长房（凌明忠）", 1},
		{"40000000-0000-4000-8000-000000000002", "40000000-0000-4000-8000-000000000001", "成铭支", 1},
		{"40000000-0000-4000-8000-000000000003", "40000000-0000-4000-8000-000000000001", "成志支", 2},
		{"40000000-0000-4000-8000-000000000004", "40000000-0000-4000-8000-000000000001", "成学支", 3},
		{"40000000-0000-4000-8000-000000000005", "", "二房（凌明龙）", 2},
		{"40000000-0000-4000-8000-000000000006", "", "明秀支", 3},
	}
	for _, branch := range branches {
		var parent any
		if branch.ParentID != "" {
			parent = branch.ParentID
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO branches (id, family_id, parent_branch_id, name, sort_order)
			VALUES (?, ?, ?, ?, ?)`,
			branch.ID, demoFamilyID, parent, branch.Name, branch.Sort,
		); err != nil {
			log.Fatalf("insert branch %s: %v", branch.Name, err)
		}
	}

	persons := []personSeed{
		{"50000000-0000-4000-8000-000000000101", "40000000-0000-4000-8000-000000000001", "凌", "明忠", "male", 1, 1, 0, "living", ""},
		{"50000000-0000-4000-8000-000000000102", "40000000-0000-4000-8000-000000000001", "陈", "友芬", "female", 1, 2, 0, "living", "凌明忠之妻。"},
		{"50000000-0000-4000-8000-000000000103", "40000000-0000-4000-8000-000000000005", "凌", "明龙", "male", 1, 1, 0, "living", "凌明忠的弟弟。"},
		{"50000000-0000-4000-8000-000000000104", "40000000-0000-4000-8000-000000000005", "江", "桂秀", "female", 1, 2, 0, "living", "凌明龙之妻。"},
		{"50000000-0000-4000-8000-000000000105", "40000000-0000-4000-8000-000000000006", "凌", "明秀", "female", 1, 3, 0, "living", "凌明忠的妹妹。"},
		{"50000000-0000-4000-8000-000000000106", "40000000-0000-4000-8000-000000000002", "凌", "成铭", "male", 2, 1, 0, "living", "凌明忠长子，凌磊之父。"},
		{"50000000-0000-4000-8000-000000000107", "40000000-0000-4000-8000-000000000002", "姚", "克凤", "female", 2, 2, 0, "living", "凌成铭之妻。"},
		{"50000000-0000-4000-8000-000000000108", "40000000-0000-4000-8000-000000000003", "凌", "成志", "male", 2, 2, 0, "living", "凌明忠三子。"},
		{"50000000-0000-4000-8000-000000000109", "40000000-0000-4000-8000-000000000003", "陈", "元娥", "female", 2, 2, 0, "living", "凌成志之妻。"},
		{"50000000-0000-4000-8000-000000000110", "40000000-0000-4000-8000-000000000004", "凌", "成学", "male", 2, 3, 0, "living", "凌明忠四子。"},
		{"50000000-0000-4000-8000-000000000111", "40000000-0000-4000-8000-000000000004", "曹", "明玲", "female", 2, 2, 0, "living", "凌成学之妻。"},
		{"50000000-0000-4000-8000-000000000112", "40000000-0000-4000-8000-000000000001", "凌", "成英", "female", 2, 4, 0, "living", "凌明忠长女。"},
		{"50000000-0000-4000-8000-000000000113", "40000000-0000-4000-8000-000000000001", "凌", "成会", "female", 2, 5, 0, "living", "凌明忠三女。"},
		{"50000000-0000-4000-8000-000000000114", "40000000-0000-4000-8000-000000000005", "凌", "成亮", "male", 2, 3, 0, "living", "凌明龙长子。"},
		{"50000000-0000-4000-8000-000000000115", "40000000-0000-4000-8000-000000000005", "凌", "成银", "male", 2, 4, 0, "living", "凌明龙次子。"},
		{"50000000-0000-4000-8000-000000000116", "40000000-0000-4000-8000-000000000002", "凌", "磊", "male", 3, 3, 0, "living", "凌成铭之子。"},
		{"50000000-0000-4000-8000-000000000117", "40000000-0000-4000-8000-000000000002", "凌", "鑫", "male", 3, 1, 0, "living", "凌磊的哥哥。"},
		{"50000000-0000-4000-8000-000000000118", "40000000-0000-4000-8000-000000000002", "凌", "继菊", "female", 3, 2, 0, "living", "凌磊的姐姐。"},
		{"50000000-0000-4000-8000-000000000119", "40000000-0000-4000-8000-000000000003", "凌", "东", "male", 3, 1, 0, "living", "凌成志之子。"},
		{"50000000-0000-4000-8000-000000000120", "40000000-0000-4000-8000-000000000003", "凌", "巧", "female", 3, 2, 0, "living", "凌成志之女。"},
		{"50000000-0000-4000-8000-000000000121", "40000000-0000-4000-8000-000000000003", "凌", "云", "male", 3, 3, 0, "living", "凌成志之子。"},
		{"50000000-0000-4000-8000-000000000122", "40000000-0000-4000-8000-000000000004", "凌", "晟轩", "male", 3, 1, 0, "living", "凌成学之子。"},
	}
	for _, person := range persons {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO persons
				(id, family_id, branch_id, surname, given_name, gender, generation_no,
				 birth_order, birth_year, birth_calendar, life_status, biography)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, 0), 'gregorian', ?, ?)`,
			person.ID, demoFamilyID, person.BranchID, person.Surname, person.GivenName,
			person.Gender, person.Generation, person.BirthOrder, person.BirthYear,
			person.LifeStatus, person.Biography,
		); err != nil {
			log.Fatalf("insert person %s%s: %v", person.Surname, person.GivenName, err)
		}
	}

	edges := []edgeSeed{
		{"50000000-0000-4000-8000-000000000101", "50000000-0000-4000-8000-000000000106", "father"},
		{"50000000-0000-4000-8000-000000000102", "50000000-0000-4000-8000-000000000106", "mother"},
		{"50000000-0000-4000-8000-000000000101", "50000000-0000-4000-8000-000000000108", "father"},
		{"50000000-0000-4000-8000-000000000102", "50000000-0000-4000-8000-000000000108", "mother"},
		{"50000000-0000-4000-8000-000000000101", "50000000-0000-4000-8000-000000000110", "father"},
		{"50000000-0000-4000-8000-000000000102", "50000000-0000-4000-8000-000000000110", "mother"},
		{"50000000-0000-4000-8000-000000000101", "50000000-0000-4000-8000-000000000112", "father"},
		{"50000000-0000-4000-8000-000000000102", "50000000-0000-4000-8000-000000000112", "mother"},
		{"50000000-0000-4000-8000-000000000101", "50000000-0000-4000-8000-000000000113", "father"},
		{"50000000-0000-4000-8000-000000000102", "50000000-0000-4000-8000-000000000113", "mother"},
		{"50000000-0000-4000-8000-000000000103", "50000000-0000-4000-8000-000000000114", "father"},
		{"50000000-0000-4000-8000-000000000104", "50000000-0000-4000-8000-000000000114", "mother"},
		{"50000000-0000-4000-8000-000000000103", "50000000-0000-4000-8000-000000000115", "father"},
		{"50000000-0000-4000-8000-000000000104", "50000000-0000-4000-8000-000000000115", "mother"},
		{"50000000-0000-4000-8000-000000000106", "50000000-0000-4000-8000-000000000116", "father"},
		{"50000000-0000-4000-8000-000000000107", "50000000-0000-4000-8000-000000000116", "mother"},
		{"50000000-0000-4000-8000-000000000106", "50000000-0000-4000-8000-000000000117", "father"},
		{"50000000-0000-4000-8000-000000000107", "50000000-0000-4000-8000-000000000117", "mother"},
		{"50000000-0000-4000-8000-000000000106", "50000000-0000-4000-8000-000000000118", "father"},
		{"50000000-0000-4000-8000-000000000107", "50000000-0000-4000-8000-000000000118", "mother"},
		{"50000000-0000-4000-8000-000000000108", "50000000-0000-4000-8000-000000000119", "father"},
		{"50000000-0000-4000-8000-000000000109", "50000000-0000-4000-8000-000000000119", "mother"},
		{"50000000-0000-4000-8000-000000000108", "50000000-0000-4000-8000-000000000120", "father"},
		{"50000000-0000-4000-8000-000000000109", "50000000-0000-4000-8000-000000000120", "mother"},
		{"50000000-0000-4000-8000-000000000108", "50000000-0000-4000-8000-000000000121", "father"},
		{"50000000-0000-4000-8000-000000000109", "50000000-0000-4000-8000-000000000121", "mother"},
		{"50000000-0000-4000-8000-000000000110", "50000000-0000-4000-8000-000000000122", "father"},
		{"50000000-0000-4000-8000-000000000111", "50000000-0000-4000-8000-000000000122", "mother"},
	}
	for index, edge := range edges {
		id := fmt.Sprintf("60000000-0000-4000-8000-%012d", index+1)
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO parent_child_relationships (id, family_id, parent_id, child_id, parent_role)
			VALUES (?, ?, ?, ?, ?)`,
			id, demoFamilyID, edge.ParentID, edge.ChildID, edge.Role,
		); err != nil {
			log.Fatalf("insert parent-child %d: %v", index+1, err)
		}
	}

	spouses := [][2]string{
		{"50000000-0000-4000-8000-000000000101", "50000000-0000-4000-8000-000000000102"},
		{"50000000-0000-4000-8000-000000000103", "50000000-0000-4000-8000-000000000104"},
		{"50000000-0000-4000-8000-000000000106", "50000000-0000-4000-8000-000000000107"},
		{"50000000-0000-4000-8000-000000000108", "50000000-0000-4000-8000-000000000109"},
		{"50000000-0000-4000-8000-000000000110", "50000000-0000-4000-8000-000000000111"},
	}
	for index, pair := range spouses {
		id := fmt.Sprintf("70000000-0000-4000-8000-%012d", index+1)
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO spouse_relationships (id, family_id, person_a_id, person_b_id, status)
			VALUES (?, ?, ?, ?, 'married')`,
			id, demoFamilyID, pair[0], pair[1],
		); err != nil {
			log.Fatalf("insert spouse %d: %v", index+1, err)
		}
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO users (id, login_name, password_hash, display_name)
		VALUES (?, 'linglei', ?, '凌磊')`,
		demoUserID, passwordHash,
	); err != nil {
		log.Fatalf("insert owner user: %v", err)
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO family_memberships (id, family_id, user_id, role, status, person_id)
		VALUES (?, ?, ?, 'owner', 'active', ?)`,
		demoMemberID, demoFamilyID, demoUserID, ownerPersonID,
	); err != nil {
		log.Fatalf("insert owner membership: %v", err)
	}

	grants := []struct {
		BranchID string
	}{
		{"40000000-0000-4000-8000-000000000001"},
		{"40000000-0000-4000-8000-000000000002"},
	}
	for index, grant := range grants {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO branch_admin_grants
				(id, family_id, branch_id, user_id, include_descendants, status, granted_by_user_id)
			VALUES (?, ?, ?, ?, 1, 'active', ?)`,
			fmt.Sprintf("80000000-0000-4000-8000-%012d", index+1),
			demoFamilyID, grant.BranchID, demoUserID, demoUserID,
		); err != nil {
			log.Fatalf("insert branch grant %d: %v", index+1, err)
		}
	}

	if err := tx.Commit(); err != nil {
		log.Fatalf("commit seed transaction: %v", err)
	}
	fmt.Println("demo data seeded")
	fmt.Println("login: linglei / Demo#2026")
}
