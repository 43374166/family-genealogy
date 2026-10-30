package store

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

var (
	ErrCodeRateLimited = errors.New("verification code rate limited")
	ErrInvalidCode     = errors.New("invalid verification code")
)

type OTPPolicy struct {
	Cooldown    time.Duration
	MaxPerHour  int
	TTL         time.Duration
	MaxAttempts int
	Pepper      string
}

func HashOTP(phone, purpose, code, pepper string) string {
	mac := hmac.New(sha256.New, []byte(pepper))
	_, _ = mac.Write([]byte(phone + "|" + purpose + "|" + code))
	return hex.EncodeToString(mac.Sum(nil))
}

func (s *Store) CreatePhoneCode(
	ctx context.Context,
	phone, userID, purpose, codeHash, ip string,
	policy OTPPolicy,
) error {
	var lastCreated sql.NullTime
	err := s.db.QueryRowContext(ctx, `
		SELECT MAX(created_at) FROM phone_verification_codes
		WHERE phone = ? AND purpose = ?`, phone, purpose,
	).Scan(&lastCreated)
	if err != nil {
		return fmt.Errorf("check otp cooldown: %w", err)
	}
	if lastCreated.Valid && time.Since(lastCreated.Time) < policy.Cooldown {
		return ErrCodeRateLimited
	}
	var hourly int
	if err := s.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM phone_verification_codes
		WHERE phone = ? AND purpose = ? AND created_at > UTC_TIMESTAMP(6) - INTERVAL 1 HOUR`,
		phone, purpose,
	).Scan(&hourly); err != nil {
		return fmt.Errorf("check otp hourly limit: %w", err)
	}
	if hourly >= policy.MaxPerHour {
		return ErrCodeRateLimited
	}
	_, err = s.db.ExecContext(ctx, `
		INSERT INTO phone_verification_codes
			(id, phone, user_id, purpose, code_hash, expires_at, max_attempts, ip)
		VALUES (?, ?, NULLIF(?, ''), ?, ?, ?, ?, ?)`,
		uuid.NewString(), phone, userID, purpose, codeHash,
		time.Now().UTC().Add(policy.TTL), policy.MaxAttempts, ip,
	)
	if err != nil {
		return fmt.Errorf("insert phone code: %w", err)
	}
	return nil
}

func (s *Store) DeletePhoneCode(ctx context.Context, phone, purpose string) error {
	_, err := s.db.ExecContext(ctx, `
		DELETE FROM phone_verification_codes
		WHERE phone = ? AND purpose = ? AND used_at IS NULL`,
		phone, purpose,
	)
	if err != nil {
		return fmt.Errorf("delete phone code: %w", err)
	}
	return nil
}

func (s *Store) VerifyPhoneCode(
	ctx context.Context,
	phone, userID, purpose, codeHash string,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin otp verification: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	query := `
		SELECT id, code_hash, attempts, max_attempts, expires_at, used_at
		FROM phone_verification_codes
		WHERE phone = ? AND purpose = ?
		  AND (? = '' OR user_id = ?)
		ORDER BY created_at DESC
		LIMIT 1 FOR UPDATE`
	var (
		id, storedHash        string
		attempts, maxAttempts int
		expiresAt             time.Time
		usedAt                sql.NullTime
	)
	err = tx.QueryRowContext(ctx, query, phone, purpose, userID, userID).Scan(
		&id, &storedHash, &attempts, &maxAttempts, &expiresAt, &usedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrInvalidCode
	}
	if err != nil {
		return fmt.Errorf("lock phone code: %w", err)
	}
	if usedAt.Valid || attempts >= maxAttempts || !expiresAt.After(time.Now().UTC()) {
		return ErrInvalidCode
	}
	matched := hmac.Equal([]byte(storedHash), []byte(codeHash))
	nextAttempts := attempts + 1
	if _, err := tx.ExecContext(ctx, `
		UPDATE phone_verification_codes
		SET attempts = ?, used_at = CASE WHEN ? OR ? >= max_attempts
			THEN UTC_TIMESTAMP(6) ELSE used_at END
		WHERE id = ?`,
		nextAttempts, matched, nextAttempts, id,
	); err != nil {
		return fmt.Errorf("update phone code attempt: %w", err)
	}
	if !matched {
		if err := tx.Commit(); err != nil {
			return fmt.Errorf("commit otp failure: %w", err)
		}
		return ErrInvalidCode
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit otp verification: %w", err)
	}
	return nil
}

func (s *Store) UserIDByPhone(ctx context.Context, phone string) (string, error) {
	var userID string
	err := s.db.QueryRowContext(ctx, `
		SELECT id FROM users
		WHERE phone = ? AND status = 'active' AND phone_verified_at IS NOT NULL
		LIMIT 1`,
		phone,
	).Scan(&userID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("lookup phone user: %w", err)
	}
	return userID, nil
}

func (s *Store) PhoneInUse(ctx context.Context, phone, exceptUserID string) (bool, error) {
	var count int
	err := s.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM users
		WHERE phone = ? AND status = 'active' AND id <> ?`,
		phone, exceptUserID,
	).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("check phone usage: %w", err)
	}
	return count > 0, nil
}

func (s *Store) BindPhone(
	ctx context.Context,
	familyID, userID, phone string,
	meta AuditMeta,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin phone bind: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	result, err := tx.ExecContext(ctx, `
		UPDATE users SET phone = ?, phone_verified_at = UTC_TIMESTAMP(6)
		WHERE id = ? AND status = 'active'`,
		phone, userID,
	)
	if err != nil {
		if isDuplicateError(err) {
			return ErrConflict
		}
		return fmt.Errorf("bind user phone: %w", err)
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("bind phone rows: %w", err)
	}
	if affected != 1 {
		return ErrNotFound
	}
	after, _ := json.Marshal(map[string]any{"phone": phone})
	if err := insertAudit(ctx, tx, familyID, userID, "user.phone_bound",
		"user", userID, "", nil, after, meta); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit phone bind: %w", err)
	}
	return nil
}
