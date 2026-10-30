package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/43374166/family-genealogy/server/internal/buildinfo"
	"github.com/43374166/family-genealogy/server/internal/config"
	"github.com/43374166/family-genealogy/server/internal/database"
	"github.com/43374166/family-genealogy/server/internal/httpapi"
	"github.com/43374166/family-genealogy/server/internal/sms"
	"github.com/43374166/family-genealogy/server/internal/store"
)

func main() {
	if err := run(); err != nil {
		slog.Error("api stopped", "error", err)
		os.Exit(1)
	}
}

func run() error {
	versionFlag := flag.Bool("version", false, "print build version and exit")
	flag.Parse()
	if *versionFlag {
		fmt.Printf("%s %s (%s)\n", buildinfo.Service, buildinfo.Version, buildinfo.Commit)
		return nil
	}

	cfg, err := config.Load()
	if err != nil {
		return err
	}

	logger := newLogger(cfg)
	slog.SetDefault(logger)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	db, err := database.Open(ctx, cfg.DatabaseDSN, cfg.DBMaxConns)
	if err != nil {
		return err
	}
	defer db.Close()

	var smsSender sms.Sender = sms.Disabled{}
	switch cfg.SMSProvider {
	case "mock":
		smsSender = sms.Mock{Logger: logger}
	case "huawei":
		huawei, err := sms.NewHuawei(
			cfg.SMSAppKey, cfg.SMSAppSecret, cfg.SMSFrom,
			cfg.SMSTemplateID, cfg.SMSSignature, cfg.SMSRegion,
		)
		if err != nil {
			return fmt.Errorf("configure Huawei SMS: %w", err)
		}
		smsSender = huawei
	}

	router := httpapi.NewRouter(httpapi.Dependencies{
		DB:     db,
		Store:  store.New(db.DB),
		Logger: logger,
		SMS:    smsSender,
		OTP: store.OTPPolicy{
			Cooldown: 60 * time.Second, MaxPerHour: 5,
			TTL: 5 * time.Minute, MaxAttempts: 5,
			Pepper: cfg.OTPPepper,
		},
	})
	server := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}

	serverErr := make(chan error, 1)
	go func() {
		logger.Info("api listening",
			"addr", cfg.HTTPAddr,
			"environment", cfg.Environment,
			"version", buildinfo.Version,
			"commit", buildinfo.Commit,
		)
		serverErr <- server.ListenAndServe()
	}()

	select {
	case err := <-serverErr:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		logger.Info("shutdown requested")
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("graceful shutdown: %w", err)
	}

	if err := <-serverErr; err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	logger.Info("api stopped cleanly")
	return nil
}

func newLogger(cfg config.Config) *slog.Logger {
	opts := &slog.HandlerOptions{Level: cfg.LogLevel}
	if cfg.Environment == "development" || cfg.Environment == "test" {
		return slog.New(slog.NewTextHandler(os.Stdout, opts))
	}
	return slog.New(slog.NewJSONHandler(os.Stdout, opts))
}
