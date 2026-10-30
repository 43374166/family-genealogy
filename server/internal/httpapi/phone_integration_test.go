package httpapi_test

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/43374166/family-genealogy/server/internal/database"
	"github.com/43374166/family-genealogy/server/internal/httpapi"
	"github.com/43374166/family-genealogy/server/internal/store"
)

func TestPhoneLoginAndBinding(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_DSN")
	if dsn == "" {
		t.Skip("TEST_DATABASE_DSN is not set; skip HTTP/MySQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	db, err := database.Open(ctx, dsn, 2)
	if err != nil {
		t.Fatalf("open test database: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	const (
		pepper     = "test-otp-pepper"
		loginPhone = "+8613900000001"
		bindPhone  = "+8613900000002"
		code       = "123456"
	)
	server := httptest.NewServer(httpapi.NewRouter(httpapi.Dependencies{
		DB:     db,
		Store:  store.New(db.DB),
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
		OTP: store.OTPPolicy{
			Cooldown: 0, MaxPerHour: 10, TTL: 5 * time.Minute,
			MaxAttempts: 5, Pepper: pepper,
		},
	}))
	t.Cleanup(server.Close)

	var ownerID string
	if err := db.DB.QueryRowContext(ctx, `
		SELECT id FROM users WHERE login_name = 'linglei'`,
	).Scan(&ownerID); err != nil {
		t.Fatalf("owner id: %v", err)
	}
	_, _ = db.DB.Exec(`UPDATE users SET phone = NULL, phone_verified_at = NULL WHERE id = ?`, ownerID)
	_, _ = db.DB.Exec(`DELETE FROM phone_verification_codes WHERE phone IN (?, ?)`, loginPhone, bindPhone)
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM phone_verification_codes WHERE phone IN (?, ?)`, loginPhone, bindPhone)
		_, _ = db.DB.Exec(`UPDATE users SET phone = NULL, phone_verified_at = NULL WHERE id = ?`, ownerID)
	})

	_, _ = db.DB.Exec(`
		INSERT INTO phone_verification_codes
			(id, phone, purpose, code_hash, expires_at, max_attempts, ip)
		VALUES (UUID(), ?, 'login', ?, UTC_TIMESTAMP(6) + INTERVAL 5 MINUTE, 5, '127.0.0.1')`,
		loginPhone, store.HashOTP(loginPhone, "login", code, pepper),
	)
	_, _ = db.DB.Exec(`UPDATE users SET phone = ?, phone_verified_at = UTC_TIMESTAMP(6) WHERE id = ?`, loginPhone, ownerID)

	response := doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/sms/login",
		fmt.Sprintf(`{"phone":%q,"code":%q}`, loginPhone, code), "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("phone login status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var session struct {
		Token string `json:"token"`
	}
	decodeBody(t, response, &session)
	if session.Token == "" {
		t.Fatal("phone login token is empty")
	}

	_, _ = db.DB.Exec(`
		INSERT INTO phone_verification_codes
			(id, phone, user_id, purpose, code_hash, expires_at, max_attempts, ip)
		VALUES (UUID(), ?, ?, 'bind', ?, UTC_TIMESTAMP(6) + INTERVAL 5 MINUTE, 5, '127.0.0.1')`,
		bindPhone, ownerID, store.HashOTP(bindPhone, "bind", code, pepper),
	)
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/phone/bind",
		fmt.Sprintf(`{"phone":%q,"code":%q}`, bindPhone, code), session.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("phone bind status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var phone string
	if err := db.DB.QueryRowContext(ctx, `
		SELECT COALESCE(phone, '') FROM users WHERE id = ?`, ownerID,
	).Scan(&phone); err != nil {
		t.Fatalf("read bound phone: %v", err)
	}
	if phone != bindPhone {
		t.Fatalf("bound phone = %q", phone)
	}
}
