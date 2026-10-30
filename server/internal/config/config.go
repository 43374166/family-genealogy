package config

import (
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Environment     string
	HTTPAddr        string
	DatabaseURL     string
	DBMaxConns      int32
	ShutdownTimeout time.Duration
	LogLevel        slog.Level
}

func Load() (Config, error) {
	cfg := Config{
		Environment:     envOrDefault("APP_ENV", "development"),
		HTTPAddr:        envOrDefault("HTTP_ADDR", ":8080"),
		DatabaseURL:     strings.TrimSpace(os.Getenv("DATABASE_URL")),
		DBMaxConns:      10,
		ShutdownTimeout: 15 * time.Second,
		LogLevel:        slog.LevelInfo,
	}

	switch cfg.Environment {
	case "development", "test", "staging", "production":
	default:
		return Config{}, fmt.Errorf("APP_ENV must be one of development, test, staging, production")
	}

	if cfg.DatabaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}

	if raw := strings.TrimSpace(os.Getenv("DB_MAX_CONNS")); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 || n > 100 {
			return Config{}, fmt.Errorf("DB_MAX_CONNS must be an integer between 1 and 100")
		}
		cfg.DBMaxConns = int32(n)
	}

	if raw := strings.TrimSpace(os.Getenv("SHUTDOWN_TIMEOUT")); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil || d < time.Second || d > 5*time.Minute {
			return Config{}, fmt.Errorf("SHUTDOWN_TIMEOUT must be between 1s and 5m")
		}
		cfg.ShutdownTimeout = d
	}

	if raw := strings.TrimSpace(os.Getenv("LOG_LEVEL")); raw != "" {
		var level slog.Level
		if err := level.UnmarshalText([]byte(raw)); err != nil {
			return Config{}, fmt.Errorf("LOG_LEVEL must be debug, info, warn, or error")
		}
		cfg.LogLevel = level
	}

	return cfg, nil
}

func envOrDefault(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}
