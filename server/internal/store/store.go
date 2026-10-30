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
		SELECT id, login_name, display_name, COALESCE(phone, ''), status, password_hash
		FROM users
		WHERE login_name = ?
		LIMIT 1`, loginName,
	).Scan(&user.ID, &user.LoginName, &user.DisplayName, &user.Phone, &user.Status, &hash)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, "", ErrNotFound
	}
	if err != nil {
		return nil, "", fmt.Errorf("lookup login user: %w", err)
	}
	return &user, hash, nil
}

func (s *Store) GetActiveUser(ctx context.Context, userID string) (*model.User, error) {
	var user model.User
	err := s.db.QueryRowContext(ctx, `
		SELECT id, login_name, display_name, COALESCE(phone, ''), status
		FROM users
		WHERE id = ? AND status = 'active'
		LIMIT 1`, userID,
	).Scan(&user.ID, &user.LoginName, &user.DisplayName, &user.Phone, &user.Status)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lookup active user: %w", err)
	}
	return &user, nil
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

func (s *Store) GetPreferredMembership(
	ctx context.Context,
	userID string,
) (*model.Membership, *model.Family, error) {
	var familyID sql.NullString
	err := s.db.QueryRowContext(ctx, `
		SELECT active_family_id FROM user_sessions
		WHERE user_id = ? AND active_family_id IS NOT NULL AND revoked_at IS NULL
		ORDER BY last_used_at DESC, created_at DESC
		LIMIT 1`, userID,
	).Scan(&familyID)
	if err == nil && familyID.Valid {
		membership, family, err := s.GetMembership(ctx, userID, familyID.String)
		if err == nil {
			return membership, family, nil
		}
		if !errors.Is(err, ErrNoMembership) && !errors.Is(err, ErrNotFound) {
			return nil, nil, err
		}
	}
	return s.GetPrimaryMembership(ctx, userID)
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
	activeFamilyID, ip, userAgent string,
) (string, error) {
	sessionID := uuid.NewString()
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO user_sessions
			(id, user_id, active_family_id, token_hash, expires_at, ip, user_agent)
		VALUES (?, ?, NULLIF(?, ''), ?, ?, NULLIF(?, ''), NULLIF(?, ''))`,
		sessionID, userID, activeFamilyID, tokenHash, expiresAt, ip, userAgent,
	)
	if err != nil {
		return "", fmt.Errorf("create session: %w", err)
	}
	return sessionID, nil
}

func (s *Store) GetMembership(
	ctx context.Context,
	userID, familyID string,
) (*model.Membership, *model.Family, error) {
	var membership model.Membership
	var personID sql.NullString
	err := s.db.QueryRowContext(ctx, `
		SELECT id, role, status, person_id, joined_at
		FROM family_memberships
		WHERE user_id = ? AND family_id = ? AND status = 'active'
		LIMIT 1`, userID, familyID,
	).Scan(
		&membership.ID, &membership.Role, &membership.Status,
		&personID, &membership.JoinedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil, ErrNoMembership
	}
	if err != nil {
		return nil, nil, fmt.Errorf("lookup family membership: %w", err)
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

func (s *Store) SwitchSessionFamily(
	ctx context.Context,
	sessionID, userID, familyID string,
) (*model.Membership, *model.Family, error) {
	membership, family, err := s.GetMembership(ctx, userID, familyID)
	if err != nil {
		return nil, nil, err
	}
	result, err := s.db.ExecContext(ctx, `
		UPDATE user_sessions SET active_family_id = ?
		WHERE id = ? AND user_id = ?`,
		familyID, sessionID, userID,
	)
	if err != nil {
		return nil, nil, fmt.Errorf("switch session family: %w", err)
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return nil, nil, fmt.Errorf("switch family rows: %w", err)
	}
	if affected != 1 {
		return nil, nil, ErrNotFound
	}
	return membership, family, nil
}

func (s *Store) ListUserFamilies(
	ctx context.Context,
	userID string,
) ([]model.FamilyMembership, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT family_id, id, role, status, person_id, joined_at
		FROM family_memberships
		WHERE user_id = ? AND status = 'active'
		ORDER BY joined_at ASC, created_at ASC`, userID,
	)
	if err != nil {
		return nil, fmt.Errorf("list user families: %w", err)
	}
	defer rows.Close()
	items := make([]model.FamilyMembership, 0)
	for rows.Next() {
		var (
			familyID, membershipID, role, status string
			personID                             sql.NullString
			joinedAt                             time.Time
		)
		if err := rows.Scan(
			&familyID, &membershipID, &role, &status, &personID, &joinedAt,
		); err != nil {
			return nil, fmt.Errorf("scan user family: %w", err)
		}
		family, err := s.GetFamily(ctx, familyID)
		if errors.Is(err, ErrNotFound) {
			continue
		}
		if err != nil {
			return nil, err
		}
		membership := model.Membership{
			ID: membershipID, Role: role, Status: status, JoinedAt: joinedAt,
		}
		if personID.Valid {
			value := personID.String
			membership.PersonID = &value
		}
		items = append(items, model.FamilyMembership{
			Family: *family, Membership: membership,
		})
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate user families: %w", err)
	}
	return items, nil
}

func (s *Store) GetPrincipal(ctx context.Context, tokenHash []byte) (*Principal, error) {
	var principal Principal
	var activeFamilyID sql.NullString
	err := s.db.QueryRowContext(ctx, `
		SELECT s.id, s.expires_at, s.active_family_id,
		       u.id, u.login_name, u.display_name, COALESCE(u.phone, ''), u.status
		FROM user_sessions s
		JOIN users u ON u.id = s.user_id
		WHERE s.token_hash = ?
		  AND s.revoked_at IS NULL
		  AND s.expires_at > UTC_TIMESTAMP(6)
		LIMIT 1`, tokenHash,
	).Scan(
		&principal.SessionID, &principal.ExpiresAt, &activeFamilyID,
		&principal.User.ID, &principal.User.LoginName,
		&principal.User.DisplayName, &principal.User.Phone, &principal.User.Status,
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

	var membership *model.Membership
	var family *model.Family
	if activeFamilyID.Valid {
		membership, family, err = s.GetMembership(
			ctx, principal.User.ID, activeFamilyID.String,
		)
	}
	if !activeFamilyID.Valid || err != nil {
		membership, family, err = s.GetPrimaryMembership(ctx, principal.User.ID)
		if err == nil && activeFamilyID.Valid {
			_, _ = s.db.ExecContext(ctx, `
				UPDATE user_sessions SET active_family_id = ? WHERE id = ?`,
				family.ID, principal.SessionID,
			)
		}
	}
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
		`UPDATE user_sessions
		 SET last_used_at = UTC_TIMESTAMP(6),
		     expires_at = DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 30 DAY)
		 WHERE id = ?`, sessionID)
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
