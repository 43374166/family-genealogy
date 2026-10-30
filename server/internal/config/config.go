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
	DatabaseDSN     string
	DBMaxConns      int32
	ShutdownTimeout time.Duration
	LogLevel        slog.Level
	SMSProvider     string
	SMSAppKey       string
	SMSAppSecret    string
	SMSFrom         string
	SMSTemplateID   string
	SMSSignature    string
	SMSRegion       string
	OTPPepper       string
}

func Load() (Config, error) {
	cfg := Config{
		Environment:     envOrDefault("APP_ENV", "development"),
		HTTPAddr:        envOrDefault("HTTP_ADDR", ":8080"),
		DatabaseDSN:     strings.TrimSpace(os.Getenv("DATABASE_DSN")),
		DBMaxConns:      10,
		ShutdownTimeout: 15 * time.Second,
		LogLevel:        slog.LevelInfo,
		SMSProvider:     envOrDefault("SMS_PROVIDER", "disabled"),
		SMSAppKey:       strings.TrimSpace(os.Getenv("HUAWEI_SMS_APP_KEY")),
		SMSAppSecret:    strings.TrimSpace(os.Getenv("HUAWEI_SMS_APP_SECRET")),
		SMSFrom:         strings.TrimSpace(os.Getenv("HUAWEI_SMS_FROM")),
		SMSTemplateID:   strings.TrimSpace(os.Getenv("HUAWEI_SMS_TEMPLATE_ID")),
		SMSSignature:    strings.TrimSpace(os.Getenv("HUAWEI_SMS_SIGNATURE")),
		SMSRegion:       envOrDefault("HUAWEI_SMS_REGION", "cn-north-4"),
		OTPPepper:       strings.TrimSpace(os.Getenv("OTP_PEPPER")),
	}

	switch cfg.Environment {
	case "development", "test", "staging", "production":
	default:
		return Config{}, fmt.Errorf("APP_ENV must be one of development, test, staging, production")
	}

	if cfg.DatabaseDSN == "" {
		return Config{}, fmt.Errorf("DATABASE_DSN is required")
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

	switch cfg.SMSProvider {
	case "disabled", "mock", "huawei":
	default:
		return Config{}, fmt.Errorf("SMS_PROVIDER must be disabled, mock, or huawei")
	}
	if cfg.OTPPepper == "" {
		cfg.OTPPepper = "development-only-otp-pepper"
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
