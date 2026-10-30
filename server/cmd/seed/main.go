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
	demoFamilyID = "10000000-0000-4000-8000-000000000001"
	demoUserID   = "20000000-0000-4000-8000-000000000001"
	demoMemberID = "30000000-0000-4000-8000-000000000001"
)

type branchSeed struct {
	ID   string
	Name string
	Sort int
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
		VALUES (?, '张氏家族', '张', '寻根溯源 · 传承家风', '江南 · 青溪',
		        '青溪张氏示例家族，用于移动端联调与接口验收。')`,
		demoFamilyID,
	); err != nil {
		log.Fatalf("insert family: %v", err)
	}

	branches := []branchSeed{
		{"40000000-0000-4000-8000-000000000001", "长房", 1},
		{"40000000-0000-4000-8000-000000000002", "二房", 2},
		{"40000000-0000-4000-8000-000000000003", "三房", 3},
		{"40000000-0000-4000-8000-000000000004", "四房", 4},
		{"40000000-0000-4000-8000-000000000005", "五房", 5},
	}
	for _, branch := range branches {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO branches (id, family_id, name, sort_order)
			VALUES (?, ?, ?, ?)`,
			branch.ID, demoFamilyID, branch.Name, branch.Sort,
		); err != nil {
			log.Fatalf("insert branch %s: %v", branch.Name, err)
		}
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO users (id, login_name, password_hash, display_name)
		VALUES (?, 'zhangsan', ?, '张三')`,
		demoUserID, passwordHash,
	); err != nil {
		log.Fatalf("insert demo user: %v", err)
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO family_memberships (id, family_id, user_id, role, status)
		VALUES (?, ?, ?, 'owner', 'active')`,
		demoMemberID, demoFamilyID, demoUserID,
	); err != nil {
		log.Fatalf("insert demo membership: %v", err)
	}

	persons := []personSeed{
		{"50000000-0000-4000-8000-000000000001", branches[0].ID, "张", "天明", "male", 6, 1, 1680, "deceased", "张氏第六世，青溪支祖。"},
		{"50000000-0000-4000-8000-000000000002", branches[0].ID, "林", "氏", "female", 6, 2, 1685, "deceased", "张天明之妻。"},
		{"50000000-0000-4000-8000-000000000003", branches[0].ID, "张", "宏远", "male", 7, 1, 1710, "deceased", "张天明之子，承继家业。"},
		{"50000000-0000-4000-8000-000000000004", branches[0].ID, "苏", "氏", "female", 7, 2, 1715, "deceased", "张宏远之妻。"},
		{"50000000-0000-4000-8000-000000000005", branches[0].ID, "张", "一", "male", 8, 1, 1998, "living", "现居青溪，热心族中公益。"},
		{"50000000-0000-4000-8000-000000000006", branches[0].ID, "余", "梦", "female", 8, 2, 2000, "living", "张一之妻。"},
		{"50000000-0000-4000-8000-000000000007", branches[1].ID, "张", "旭", "male", 9, 1, 2019, "living", ""},
		{"50000000-0000-4000-8000-000000000008", branches[1].ID, "张", "瑶", "female", 9, 2, 2020, "living", ""},
		{"50000000-0000-4000-8000-000000000009", branches[2].ID, "张", "浪", "male", 9, 3, 2018, "living", ""},
		{"50000000-0000-4000-8000-000000000010", branches[2].ID, "张", "雪", "female", 9, 4, 2017, "living", ""},
		{"50000000-0000-4000-8000-000000000011", branches[3].ID, "张", "轩", "male", 9, 5, 2021, "living", ""},
		{"50000000-0000-4000-8000-000000000012", branches[1].ID, "张", "小虎", "male", 10, 1, 2023, "living", ""},
		{"50000000-0000-4000-8000-000000000013", branches[1].ID, "张", "小雨", "female", 10, 2, 2024, "living", ""},
		{"50000000-0000-4000-8000-000000000014", branches[3].ID, "张", "小月", "female", 10, 1, 2025, "living", ""},
		{"50000000-0000-4000-8000-000000000015", branches[3].ID, "张", "小宇", "male", 10, 2, 2026, "living", ""},
	}
	for _, person := range persons {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO persons
				(id, family_id, branch_id, surname, given_name, gender, generation_no,
				 birth_order, birth_year, birth_calendar, life_status, biography)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'gregorian', ?, ?)`,
			person.ID, demoFamilyID, person.BranchID, person.Surname, person.GivenName,
			person.Gender, person.Generation, person.BirthOrder, person.BirthYear,
			person.LifeStatus, person.Biography,
		); err != nil {
			log.Fatalf("insert person %s%s: %v", person.Surname, person.GivenName, err)
		}
	}

	edges := []edgeSeed{
		{"50000000-0000-4000-8000-000000000001", "50000000-0000-4000-8000-000000000003", "father"},
		{"50000000-0000-4000-8000-000000000002", "50000000-0000-4000-8000-000000000003", "mother"},
		{"50000000-0000-4000-8000-000000000003", "50000000-0000-4000-8000-000000000005", "father"},
		{"50000000-0000-4000-8000-000000000004", "50000000-0000-4000-8000-000000000005", "mother"},
		{"50000000-0000-4000-8000-000000000005", "50000000-0000-4000-8000-000000000007", "father"},
		{"50000000-0000-4000-8000-000000000006", "50000000-0000-4000-8000-000000000007", "mother"},
		{"50000000-0000-4000-8000-000000000005", "50000000-0000-4000-8000-000000000008", "father"},
		{"50000000-0000-4000-8000-000000000006", "50000000-0000-4000-8000-000000000008", "mother"},
		{"50000000-0000-4000-8000-000000000005", "50000000-0000-4000-8000-000000000009", "father"},
		{"50000000-0000-4000-8000-000000000006", "50000000-0000-4000-8000-000000000009", "mother"},
		{"50000000-0000-4000-8000-000000000005", "50000000-0000-4000-8000-000000000010", "father"},
		{"50000000-0000-4000-8000-000000000006", "50000000-0000-4000-8000-000000000010", "mother"},
		{"50000000-0000-4000-8000-000000000005", "50000000-0000-4000-8000-000000000011", "father"},
		{"50000000-0000-4000-8000-000000000006", "50000000-0000-4000-8000-000000000011", "mother"},
		{"50000000-0000-4000-8000-000000000008", "50000000-0000-4000-8000-000000000012", "mother"},
		{"50000000-0000-4000-8000-000000000008", "50000000-0000-4000-8000-000000000013", "mother"},
		{"50000000-0000-4000-8000-000000000011", "50000000-0000-4000-8000-000000000014", "father"},
		{"50000000-0000-4000-8000-000000000011", "50000000-0000-4000-8000-000000000015", "father"},
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
		{"50000000-0000-4000-8000-000000000001", "50000000-0000-4000-8000-000000000002"},
		{"50000000-0000-4000-8000-000000000003", "50000000-0000-4000-8000-000000000004"},
		{"50000000-0000-4000-8000-000000000005", "50000000-0000-4000-8000-000000000006"},
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

	if err := tx.Commit(); err != nil {
		log.Fatalf("commit seed transaction: %v", err)
	}
	fmt.Println("demo data seeded")
	fmt.Println("login: zhangsan / Demo#2026")
}
