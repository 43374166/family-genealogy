package database

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/go-sql-driver/mysql"
)

// DB is a small wrapper around database/sql so the HTTP layer can depend on a
// Ping(context.Context) error contract without knowing the driver.
type DB struct {
	*sql.DB
}

// Open creates a bounded MySQL connection pool and verifies connectivity.
func Open(ctx context.Context, dsn string, maxConns int32) (*DB, error) {
	cfg, err := mysql.ParseDSN(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse MySQL DSN: %w", err)
	}
	// Time values must round-trip as time.Time in UTC.
	cfg.ParseTime = true
	if cfg.Loc == nil {
		cfg.Loc = time.UTC
	}

	db, err := sql.Open("mysql", cfg.FormatDSN())
	if err != nil {
		return nil, fmt.Errorf("open MySQL handle: %w", err)
	}

	if maxConns < 1 {
		maxConns = 1
	}
	db.SetMaxOpenConns(int(maxConns))
	db.SetMaxIdleConns(int(maxConns))
	db.SetConnMaxLifetime(30 * time.Minute)
	db.SetConnMaxIdleTime(5 * time.Minute)

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := db.PingContext(pingCtx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("ping MySQL: %w", err)
	}

	return &DB{DB: db}, nil
}

func (d *DB) Ping(ctx context.Context) error {
	return d.DB.PingContext(ctx)
}
