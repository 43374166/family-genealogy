package database

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/database/migrations"
	_ "github.com/go-sql-driver/mysql"
	"github.com/pressly/goose/v3"
)

// Migrate applies the embedded MySQL migrations. PostgreSQL 17 DDL is kept in
// migrations/postgres as the design reference and is not used at runtime.
func Migrate(ctx context.Context, dsn, command string) error {
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return fmt.Errorf("open migration connection: %w", err)
	}
	defer db.Close()
	db.SetMaxOpenConns(1)

	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("mysql"); err != nil {
		return fmt.Errorf("set migration dialect: %w", err)
	}

	switch strings.ToLower(strings.TrimSpace(command)) {
	case "up":
		return goose.UpContext(ctx, db, "mysql")
	case "down":
		return goose.DownContext(ctx, db, "mysql")
	case "status":
		return goose.StatusContext(ctx, db, "mysql")
	case "version":
		return goose.VersionContext(ctx, db, "mysql")
	default:
		return fmt.Errorf("unsupported migration command %q; use up, down, status, or version", command)
	}
}
