package database

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/database/migrations"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
)

// Migrate applies the embedded migrations through the pgx stdlib adapter.
// Migrations run as a separate operational step; the API never auto-migrates.
func Migrate(ctx context.Context, dsn, command string) error {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return fmt.Errorf("open migration connection: %w", err)
	}
	defer db.Close()
	db.SetMaxOpenConns(1)

	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("set migration dialect: %w", err)
	}

	switch strings.ToLower(strings.TrimSpace(command)) {
	case "up":
		return goose.UpContext(ctx, db, ".")
	case "down":
		return goose.DownContext(ctx, db, ".")
	case "status":
		return goose.StatusContext(ctx, db, ".")
	case "version":
		return goose.VersionContext(ctx, db, ".")
	default:
		return fmt.Errorf("unsupported migration command %q; use up, down, status, or version", command)
	}
}
