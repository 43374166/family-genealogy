package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

var (
	ErrNotFound     = errors.New("not found")
	ErrUnauthorized = errors.New("unauthorized")
	ErrNoMembership = errors.New("user has no active family membership")
)

type Store struct {
	db *sql.DB
}

func New(db *sql.DB) *Store {
	return &Store{db: db}
}

type Principal struct {
	SessionID  string
	ExpiresAt  time.Time
	User       model.User
	Membership model.Membership
	Family     model.Family
}

func (s *Store) GetLoginUser(ctx context.Context, loginName string) (*model.User, string, error) {
	var user model.User
	var hash string
	err := s.db.QueryRowContext(ctx, `
		SELECT id, login_name, display_name, status, password_hash
		FROM users
		WHERE login_name = ?
		LIMIT 1`, loginName,
	).Scan(&user.ID, &user.LoginName, &user.DisplayName, &user.Status, &hash)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, "", ErrNotFound
	}
	if err != nil {
		return nil, "", fmt.Errorf("lookup login user: %w", err)
	}
	return &user, hash, nil
}

func (s *Store) GetPrimaryMembership(ctx context.Context, userID string) (*model.Membership, *model.Family, error) {
	var membership model.Membership
	var personID sql.NullString
	var familyID string
	err := s.db.QueryRowContext(ctx, `
		SELECT id, role, status, person_id, joined_at, family_id
		FROM family_memberships
		WHERE user_id = ? AND status = 'active'
		ORDER BY joined_at ASC, created_at ASC
		LIMIT 1`, userID,
	).Scan(&membership.ID, &membership.Role, &membership.Status, &personID, &membership.JoinedAt, &familyID)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil, ErrNoMembership
	}
	if err != nil {
		return nil, nil, fmt.Errorf("lookup membership: %w", err)
	}
	if personID.Valid {
		v := personID.String
		membership.PersonID = &v
	}
	family, err := s.GetFamily(ctx, familyID)
	if err != nil {
		return nil, nil, err
	}
	return &membership, family, nil
}

func (s *Store) GetFamily(ctx context.Context, familyID string) (*model.Family, error) {
	var family model.Family
	err := s.db.QueryRowContext(ctx, `
		SELECT f.id, f.name, f.surname, f.motto, f.region, f.description, f.status, f.version,
		       (SELECT COUNT(*) FROM persons p WHERE p.family_id = f.id AND p.status = 'active'),
		       (SELECT COUNT(*) FROM branches b WHERE b.family_id = f.id)
		FROM families f
		WHERE f.id = ? AND f.status = 'active'
		LIMIT 1`, familyID,
	).Scan(
		&family.ID, &family.Name, &family.Surname, &family.Motto,
		&family.Region, &family.Description, &family.Status, &family.Version,
		&family.MemberCount, &family.BranchCount,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lookup family: %w", err)
	}
	return &family, nil
}

func (s *Store) CreateSession(
	ctx context.Context,
	userID string,
	tokenHash []byte,
	expiresAt time.Time,
	ip, userAgent string,
) (string, error) {
	sessionID := uuid.NewString()
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO user_sessions (id, user_id, token_hash, expires_at, ip, user_agent)
		VALUES (?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''))`,
		sessionID, userID, tokenHash, expiresAt, ip, userAgent,
	)
	if err != nil {
		return "", fmt.Errorf("create session: %w", err)
	}
	return sessionID, nil
}

func (s *Store) GetPrincipal(ctx context.Context, tokenHash []byte) (*Principal, error) {
	var principal Principal
	err := s.db.QueryRowContext(ctx, `
		SELECT s.id, s.expires_at,
		       u.id, u.login_name, u.display_name, u.status
		FROM user_sessions s
		JOIN users u ON u.id = s.user_id
		WHERE s.token_hash = ?
		  AND s.revoked_at IS NULL
		  AND s.expires_at > UTC_TIMESTAMP(6)
		LIMIT 1`, tokenHash,
	).Scan(
		&principal.SessionID, &principal.ExpiresAt,
		&principal.User.ID, &principal.User.LoginName,
		&principal.User.DisplayName, &principal.User.Status,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrUnauthorized
	}
	if err != nil {
		return nil, fmt.Errorf("lookup session: %w", err)
	}
	if principal.User.Status != "active" {
		return nil, ErrUnauthorized
	}

	membership, family, err := s.GetPrimaryMembership(ctx, principal.User.ID)
	if err != nil {
		if errors.Is(err, ErrNoMembership) {
			return nil, ErrUnauthorized
		}
		return nil, err
	}
	principal.Membership = *membership
	principal.Family = *family
	return &principal, nil
}

func (s *Store) TouchSession(ctx context.Context, sessionID string) error {
	_, err := s.db.ExecContext(ctx,
		`UPDATE user_sessions SET last_used_at = UTC_TIMESTAMP(6) WHERE id = ?`, sessionID)
	if err != nil {
		return fmt.Errorf("touch session: %w", err)
	}
	return nil
}

func (s *Store) RevokeSession(ctx context.Context, sessionID string) error {
	_, err := s.db.ExecContext(ctx,
		`UPDATE user_sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE id = ? AND revoked_at IS NULL`,
		sessionID,
	)
	if err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}
	return nil
}

func (s *Store) UpdateLastLogin(ctx context.Context, userID string) error {
	_, err := s.db.ExecContext(ctx,
		`UPDATE users SET last_login_at = UTC_TIMESTAMP(6) WHERE id = ?`, userID)
	if err != nil {
		return fmt.Errorf("update last login: %w", err)
	}
	return nil
}
