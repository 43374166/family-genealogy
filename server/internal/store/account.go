package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

func (s *Store) ChangePassword(
	ctx context.Context, userID, currentSessionID, passwordHash string,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin password change: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, `
		UPDATE users
		SET password_hash = ?, failed_login_attempts = 0, locked_until = NULL
		WHERE id = ? AND status = 'active'`, passwordHash, userID); err != nil {
		return fmt.Errorf("change password: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE user_sessions SET revoked_at = UTC_TIMESTAMP(6)
		WHERE user_id = ? AND id <> ? AND revoked_at IS NULL`,
		userID, currentSessionID); err != nil {
		return fmt.Errorf("revoke other sessions: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit password change: %w", err)
	}
	return nil
}

func (s *Store) TransferFamilyOwner(
	ctx context.Context, familyID, currentOwnerID, targetUserID string, meta AuditMeta,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin owner transfer: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	var role string
	if err := tx.QueryRowContext(ctx, `
		SELECT role FROM family_memberships
		WHERE family_id = ? AND user_id = ? AND status = 'active'
		FOR UPDATE`, familyID, currentOwnerID,
	).Scan(&role); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrForbidden
		}
		return fmt.Errorf("lock current owner: %w", err)
	}
	if role != "owner" {
		return ErrForbidden
	}
	var targetRole string
	if err := tx.QueryRowContext(ctx, `
		SELECT role FROM family_memberships
		WHERE family_id = ? AND user_id = ? AND status = 'active'
		FOR UPDATE`, familyID, targetUserID,
	).Scan(&targetRole); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return fmt.Errorf("lock target owner: %w", err)
	}
	if targetUserID == currentOwnerID {
		return ErrInvalidRequest
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_memberships SET role = 'member'
		WHERE family_id = ? AND user_id = ? AND status = 'active'`,
		familyID, currentOwnerID); err != nil {
		return fmt.Errorf("demote current owner: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_memberships SET role = 'owner'
		WHERE family_id = ? AND user_id = ? AND status = 'active'`,
		familyID, targetUserID); err != nil {
		return fmt.Errorf("promote target owner: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"fromUserId": currentOwnerID, "toUserId": targetUserID,
	})
	if err := insertAudit(ctx, tx, familyID, currentOwnerID, "family.owner_transferred",
		"family", familyID, "", nil, after, meta); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit owner transfer: %w", err)
	}
	return nil
}

func (s *Store) LoginLockedUntil(ctx context.Context, loginName string) (time.Time, error) {
	var locked sql.NullTime
	err := s.db.QueryRowContext(ctx, `
		SELECT locked_until FROM users WHERE login_name = ? LIMIT 1`,
		loginName,
	).Scan(&locked)
	if errors.Is(err, sql.ErrNoRows) {
		return time.Time{}, ErrNotFound
	}
	if err != nil {
		return time.Time{}, fmt.Errorf("lookup login lock: %w", err)
	}
	if !locked.Valid || !locked.Time.After(time.Now().UTC()) {
		return time.Time{}, nil
	}
	return locked.Time, nil
}

func (s *Store) RecordFailedLogin(ctx context.Context, userID string) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE users
		SET failed_login_attempts = failed_login_attempts + 1,
		    locked_until = CASE
		      WHEN failed_login_attempts + 1 >= 5
		      THEN UTC_TIMESTAMP(6) + INTERVAL 15 MINUTE
		      ELSE locked_until
		    END
		WHERE id = ?`, userID)
	if err != nil {
		return fmt.Errorf("record failed login: %w", err)
	}
	return nil
}

func (s *Store) ResetFailedLogin(ctx context.Context, userID string) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE users
		SET failed_login_attempts = 0, locked_until = NULL
		WHERE id = ?`, userID)
	if err != nil {
		return fmt.Errorf("reset failed login: %w", err)
	}
	return nil
}

func (s *Store) SetRecoveryCodeHash(ctx context.Context, userID, hash string) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE users
		SET recovery_code_hash = ?, recovery_code_created_at = UTC_TIMESTAMP(6)
		WHERE id = ? AND status = 'active'`, hash, userID)
	if err != nil {
		return fmt.Errorf("set recovery code: %w", err)
	}
	return nil
}

func (s *Store) RecoveryCodeHash(ctx context.Context, loginName string) (string, string, error) {
	var userID string
	var hash sql.NullString
	err := s.db.QueryRowContext(ctx, `
		SELECT id, recovery_code_hash FROM users
		WHERE login_name = ? AND status = 'active' LIMIT 1`,
		loginName,
	).Scan(&userID, &hash)
	if errors.Is(err, sql.ErrNoRows) || !hash.Valid || hash.String == "" {
		return "", "", ErrNotFound
	}
	if err != nil {
		return "", "", fmt.Errorf("lookup recovery code: %w", err)
	}
	return userID, hash.String, nil
}

func (s *Store) ResetPasswordWithRecovery(ctx context.Context, userID, passwordHash string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin password reset: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, `
		UPDATE users
		SET password_hash = ?, recovery_code_hash = NULL,
		    recovery_code_created_at = NULL, failed_login_attempts = 0,
		    locked_until = NULL
		WHERE id = ? AND status = 'active'`, passwordHash, userID); err != nil {
		return fmt.Errorf("reset password: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE user_sessions SET revoked_at = UTC_TIMESTAMP(6)
		WHERE user_id = ? AND revoked_at IS NULL`, userID); err != nil {
		return fmt.Errorf("revoke password sessions: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit password reset: %w", err)
	}
	return nil
}

func (s *Store) AcceptTerms(ctx context.Context, userID, version string) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE users
		SET terms_accepted_at = UTC_TIMESTAMP(6), terms_version = ?
		WHERE id = ? AND status = 'active'`, version, userID)
	if err != nil {
		return fmt.Errorf("accept terms: %w", err)
	}
	return nil
}

// AnonymizeAccount removes the login identity and memberships while keeping
// family-owned records (people, photos, stories) intact. The row itself stays
// so foreign keys and audit history remain valid.
func (s *Store) AnonymizeAccount(ctx context.Context, userID, passwordHash string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin account deletion: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var ownedFamilies int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM family_memberships
		WHERE user_id = ? AND role = 'owner' AND status = 'active'`,
		userID,
	).Scan(&ownedFamilies); err != nil {
		return fmt.Errorf("check account ownership: %w", err)
	}
	if ownedFamilies > 0 {
		return ErrConflict
	}
	statements := []string{
		`DELETE FROM notifications WHERE user_id = ?`,
		`DELETE FROM user_sessions WHERE user_id = ?`,
		`DELETE FROM branch_admin_grants WHERE user_id = ?`,
		`DELETE FROM family_memberships WHERE user_id = ?`,
	}
	for _, statement := range statements {
		if _, err := tx.ExecContext(ctx, statement, userID); err != nil {
			return fmt.Errorf("delete account relations: %w", err)
		}
	}
	result, err := tx.ExecContext(ctx, `
		UPDATE users
		SET login_name = ?, display_name = '已注销用户', phone = NULL,
		    email = NULL, password_hash = ?, status = 'disabled',
		    phone_verified_at = NULL, terms_accepted_at = NULL, terms_version = ''
		WHERE id = ? AND status = 'active'`,
		"deleted_"+uuid.NewString(), passwordHash, userID)
	if err != nil {
		return fmt.Errorf("anonymize account: %w", err)
	}
	affected, _ := result.RowsAffected()
	if affected != 1 {
		if affected == 0 {
			return ErrNotFound
		}
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit account deletion: %w", err)
	}
	return nil
}
