package config

import (
	"testing"
)

func TestLoadRequiresDatabaseURL(t *testing.T) {
	t.Setenv("DATABASE_DSN", "  ")
	t.Setenv("APP_ENV", "test")

	if _, err := Load(); err == nil {
		t.Fatal("expected an error when DATABASE_DSN is empty")
	}
}

func TestLoadDefaults(t *testing.T) {
	t.Setenv("DATABASE_DSN", "postgres://example")
	t.Setenv("APP_ENV", "")
	t.Setenv("HTTP_ADDR", "")
	t.Setenv("DB_MAX_CONNS", "")
	t.Setenv("SHUTDOWN_TIMEOUT", "")
	t.Setenv("LOG_LEVEL", "")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.Environment != "development" {
		t.Fatalf("Environment = %q", cfg.Environment)
	}
	if cfg.HTTPAddr != ":8080" {
		t.Fatalf("HTTPAddr = %q", cfg.HTTPAddr)
	}
	if cfg.DBMaxConns != 10 {
		t.Fatalf("DBMaxConns = %d", cfg.DBMaxConns)
	}
}

func TestLoadRejectsUsefulMisconfiguration(t *testing.T) {
	t.Setenv("DATABASE_DSN", "postgres://example")
	t.Setenv("APP_ENV", "development")
	t.Setenv("DB_MAX_CONNS", "0")

	if _, err := Load(); err == nil {
		t.Fatal("expected an error for DB_MAX_CONNS=0")
	}
}

func TestLoadRejectsUnknownLogLevel(t *testing.T) {
	t.Setenv("DATABASE_DSN", "postgres://example")
	t.Setenv("APP_ENV", "development")
	t.Setenv("LOG_LEVEL", "verbose")

	if _, err := Load(); err == nil {
		t.Fatal("expected an error for an unsupported log level")
	}
}
