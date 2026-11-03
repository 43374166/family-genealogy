package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
)

var (
	ErrQRExpired = errors.New("qr login expired")
	ErrQRState   = errors.New("qr login is not in the required state")
	ErrQRLimit   = errors.New("too many qr login attempts")
)

type QRLoginCreateInput struct {
	ID                 string
	SecretHash         []byte
	RequesterIP        string
	RequesterCity      string
	RequesterRegion    string
	RequesterCountry   string
	RequesterUserAgent string
	RequesterDevice    string
	ExpiresAt          time.Time
}

func (s *Store) CreateQRLoginSession(ctx context.Context, input QRLoginCreateInput) error {
	now := time.Now().UTC()
	var pending int
	if input.RequesterIP != "" {
		if err := s.db.QueryRowContext(ctx, `
			SELECT COUNT(*) FROM auth_qr_sessions
			WHERE requester_ip = ? AND created_at > ? AND status IN ('pending', 'scanned')`,
			input.RequesterIP, now.Add(-time.Hour),
		).Scan(&pending); err != nil {
			return fmt.Errorf("count qr login attempts: %w", err)
		}
		if pending >= 30 {
			return ErrQRLimit
		}
	}
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO auth_qr_sessions
			(id, secret_hash, status, requester_ip, requester_city, requester_region,
			 requester_country, requester_user_agent, requester_device, created_at, expires_at)
		VALUES (?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?)`,
		input.ID, input.SecretHash, input.RequesterIP, input.RequesterCity,
		input.RequesterRegion, input.RequesterCountry, input.RequesterUserAgent,
		input.RequesterDevice, now, input.ExpiresAt.UTC(),
	)
	if err != nil {
		return fmt.Errorf("create qr login session: %w", err)
	}
	// Opportunistic cleanup; expired rows are useless after one day.
	_, _ = s.db.ExecContext(ctx, `
		DELETE FROM auth_qr_sessions WHERE expires_at < ? LIMIT 200`, now.Add(-24*time.Hour))
	return nil
}

func (s *Store) GetQRLoginSession(ctx context.Context, id string, secretHash []byte) (*model.QRLoginSession, error) {
	row, err := s.qrLoginByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if !equalBytes(row.secretHash, secretHash) {
		return nil, ErrNotFound
	}
	session := row.session
	if session.Status == model.QRStatusPending ||
		session.Status == model.QRStatusScanned ||
		session.Status == model.QRStatusConfirmed {
		if !session.ExpiresAt.After(time.Now().UTC()) {
			_, _ = s.db.ExecContext(ctx, `
				UPDATE auth_qr_sessions SET status = 'expired'
				WHERE id = ? AND status IN ('pending', 'scanned', 'confirmed')`, id)
			session.Status = model.QRStatusExpired
		}
	}
	return &session, nil
}

func (s *Store) MarkQRLoginScanned(
	ctx context.Context, id string, secretHash []byte, userID string,
) (*model.QRLoginSession, error) {
	now := time.Now().UTC()
	result, err := s.db.ExecContext(ctx, `
		UPDATE auth_qr_sessions
		SET status = 'scanned', scanned_user_id = ?, scanned_at = ?
		WHERE id = ? AND secret_hash = ? AND status = 'pending' AND expires_at > ?`,
		userID, now, id, secretHash, now,
	)
	if err != nil {
		return nil, fmt.Errorf("mark qr scanned: %w", err)
	}
	if affected, _ := result.RowsAffected(); affected != 1 {
		return nil, s.qrStateError(ctx, id, secretHash)
	}
	row, err := s.qrLoginByID(ctx, id)
	if err != nil {
		return nil, err
	}
	return &row.session, nil
}

func (s *Store) ConfirmQRLogin(
	ctx context.Context, id string, secretHash []byte, userID, familyID string,
) (*model.QRLoginSession, error) {
	now := time.Now().UTC()
	result, err := s.db.ExecContext(ctx, `
		UPDATE auth_qr_sessions
		SET status = 'confirmed', user_id = ?, family_id = ?, confirmed_at = ?
		WHERE id = ? AND secret_hash = ? AND status = 'scanned'
		  AND scanned_user_id = ? AND expires_at > ?`,
		userID, familyID, now, id, secretHash, userID, now,
	)
	if err != nil {
		return nil, fmt.Errorf("confirm qr login: %w", err)
	}
	if affected, _ := result.RowsAffected(); affected != 1 {
		return nil, s.qrStateError(ctx, id, secretHash)
	}
	row, err := s.qrLoginByID(ctx, id)
	if err != nil {
		return nil, err
	}
	return &row.session, nil
}

// ConsumeQRLogin atomically marks a confirmed QR as consumed and returns the
// user/family selected on the phone. Only the first poll can obtain a session.
func (s *Store) ConsumeQRLogin(
	ctx context.Context, id string, secretHash []byte,
) (*model.QRLoginSession, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin qr consume: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	row, err := s.qrLoginByIDTx(ctx, tx, id)
	if err != nil {
		return nil, err
	}
	if !equalBytes(row.secretHash, secretHash) {
		return nil, ErrNotFound
	}
	session := row.session
	if !session.ExpiresAt.After(time.Now().UTC()) {
		_, _ = tx.ExecContext(ctx, `
			UPDATE auth_qr_sessions SET status = 'expired'
			WHERE id = ? AND status IN ('pending', 'scanned', 'confirmed')`, id)
		return nil, ErrQRExpired
	}
	if session.Status != model.QRStatusConfirmed || session.UserID == nil || session.FamilyID == nil {
		return nil, ErrQRState
	}
	now := time.Now().UTC()
	result, err := tx.ExecContext(ctx, `
		UPDATE auth_qr_sessions SET status = 'consumed', consumed_at = ?
		WHERE id = ? AND status = 'confirmed'`, now, id)
	if err != nil {
		return nil, fmt.Errorf("consume qr login: %w", err)
	}
	if affected, _ := result.RowsAffected(); affected != 1 {
		return nil, ErrQRState
	}
	session.Status = model.QRStatusConsumed
	session.ConsumedAt = &now
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit qr consume: %w", err)
	}
	return &session, nil
}

func (s *Store) CancelQRLogin(ctx context.Context, id string, secretHash []byte) error {
	now := time.Now().UTC()
	result, err := s.db.ExecContext(ctx, `
		UPDATE auth_qr_sessions
		SET status = 'cancelled', consumed_at = ?
		WHERE id = ? AND secret_hash = ? AND status IN ('pending', 'scanned')`,
		now, id, secretHash,
	)
	if err != nil {
		return fmt.Errorf("cancel qr login: %w", err)
	}
	if affected, _ := result.RowsAffected(); affected != 1 {
		return s.qrStateError(ctx, id, secretHash)
	}
	return nil
}

func (s *Store) qrStateError(ctx context.Context, id string, secretHash []byte) error {
	row, err := s.qrLoginByID(ctx, id)
	if err != nil {
		return err
	}
	if !equalBytes(row.secretHash, secretHash) {
		return ErrNotFound
	}
	if !row.session.ExpiresAt.After(time.Now().UTC()) {
		return ErrQRExpired
	}
	return ErrQRState
}

type qrLoginRow struct {
	secretHash []byte
	session    model.QRLoginSession
}

func (s *Store) qrLoginByID(ctx context.Context, id string) (*qrLoginRow, error) {
	return scanQRLoginRow(s.db.QueryRowContext(ctx, `
		SELECT id, secret_hash, status, requester_ip, requester_city, requester_region,
		       requester_country, requester_user_agent, requester_device,
		       scanned_user_id, user_id, family_id, created_at, expires_at,
		       scanned_at, confirmed_at, consumed_at
		FROM auth_qr_sessions WHERE id = ? LIMIT 1`, id))
}

func (s *Store) qrLoginByIDTx(
	ctx context.Context, tx *sql.Tx, id string,
) (*qrLoginRow, error) {
	return scanQRLoginRow(tx.QueryRowContext(ctx, `
		SELECT id, secret_hash, status, requester_ip, requester_city, requester_region,
		       requester_country, requester_user_agent, requester_device,
		       scanned_user_id, user_id, family_id, created_at, expires_at,
		       scanned_at, confirmed_at, consumed_at
		FROM auth_qr_sessions WHERE id = ? LIMIT 1 FOR UPDATE`, id))
}

func scanQRLoginRow(row *sql.Row) (*qrLoginRow, error) {
	var (
		result      qrLoginRow
		scannedUser sql.NullString
		userID      sql.NullString
		familyID    sql.NullString
		scannedAt   sql.NullTime
		confirmedAt sql.NullTime
		consumedAt  sql.NullTime
	)
	err := row.Scan(
		&result.session.ID, &result.secretHash, &result.session.Status,
		&result.session.RequesterIP, &result.session.RequesterCity,
		&result.session.RequesterRegion, &result.session.RequesterCountry,
		&result.session.RequesterUserAgent, &result.session.RequesterDevice,
		&scannedUser, &userID, &familyID, &result.session.CreatedAt,
		&result.session.ExpiresAt, &scannedAt, &confirmedAt, &consumedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("scan qr login: %w", err)
	}
	if scannedUser.Valid {
		result.session.ScannedUserID = &scannedUser.String
	}
	if userID.Valid {
		result.session.UserID = &userID.String
	}
	if familyID.Valid {
		result.session.FamilyID = &familyID.String
	}
	if scannedAt.Valid {
		result.session.ScannedAt = &scannedAt.Time
	}
	if confirmedAt.Valid {
		result.session.ConfirmedAt = &confirmedAt.Time
	}
	if consumedAt.Valid {
		result.session.ConsumedAt = &consumedAt.Time
	}
	return &result, nil
}

func equalBytes(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	var different byte
	for i := range a {
		different |= a[i] ^ b[i]
	}
	return different == 0
}
