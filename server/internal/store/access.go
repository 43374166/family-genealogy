package store

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

type RegisterInput struct {
	LoginName    string
	DisplayName  string
	Phone        string
	PasswordHash string
	InviteCode   string
}

type InviteInput struct {
	Role      string
	BranchID  string
	MaxUses   int
	ExpiresAt time.Time
}

func (s *Store) CreateInvite(
	ctx context.Context,
	familyID, actorUserID string,
	input InviteInput,
	meta AuditMeta,
) (*model.Invite, error) {
	if input.Role != "member" && input.Role != "admin" {
		return nil, ErrInvalidRequest
	}
	if input.MaxUses < 1 || input.MaxUses > 100 {
		return nil, ErrInvalidRequest
	}
	if !input.ExpiresAt.After(time.Now().UTC()) {
		return nil, ErrInvalidRequest
	}
	var branchName string
	var branchID sql.NullString
	if input.BranchID != "" {
		if err := s.db.QueryRowContext(ctx, `
			SELECT id, name FROM branches WHERE family_id = ? AND id = ?`,
			familyID, input.BranchID,
		).Scan(&branchID, &branchName); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, ErrNotFound
			}
			return nil, fmt.Errorf("lookup invite branch: %w", err)
		}
	} else if input.Role == "admin" {
		return nil, ErrInvalidRequest
	}
	if branchID.Valid {
		input.BranchID = branchID.String
	}

	var code string
	for attempt := 0; attempt < 8; attempt++ {
		code = randomInviteCode()
		_, err := s.db.ExecContext(ctx, `
			INSERT INTO family_invites
				(id, family_id, code, role, branch_id, max_uses, expires_at,
				 created_by_user_id, status)
			VALUES (?, ?, ?, ?, NULLIF(?, ''), ?, ?, ?, 'active')`,
			uuid.NewString(), familyID, code, input.Role, input.BranchID,
			input.MaxUses, input.ExpiresAt, actorUserID,
		)
		if err == nil {
			invite, lookupErr := s.inviteByCode(ctx, familyID, code)
			if lookupErr != nil {
				return nil, lookupErr
			}
			return invite, nil
		}
		if !isDuplicateError(err) {
			return nil, fmt.Errorf("insert invite: %w", err)
		}
	}
	return nil, fmt.Errorf("generate unique invite code")
}

func (s *Store) ListInvites(ctx context.Context, familyID string) ([]model.Invite, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT i.id, i.code, i.role, i.branch_id, COALESCE(b.name, ''),
		       i.max_uses, i.used_count, i.expires_at, i.status
		FROM family_invites i
		LEFT JOIN branches b ON b.id = i.branch_id AND b.family_id = i.family_id
		WHERE i.family_id = ?
		ORDER BY i.created_at DESC
		LIMIT 50`, familyID)
	if err != nil {
		return nil, fmt.Errorf("list invites: %w", err)
	}
	defer rows.Close()
	invites := make([]model.Invite, 0)
	for rows.Next() {
		invite, err := scanInvite(rows)
		if err != nil {
			return nil, err
		}
		invites = append(invites, *invite)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate invites: %w", err)
	}
	return invites, nil
}

func (s *Store) inviteByCode(ctx context.Context, familyID, code string) (*model.Invite, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT i.id, i.code, i.role, i.branch_id, COALESCE(b.name, ''),
		       i.max_uses, i.used_count, i.expires_at, i.status
		FROM family_invites i
		LEFT JOIN branches b ON b.id = i.branch_id AND b.family_id = i.family_id
		WHERE i.family_id = ? AND i.code = ?`, familyID, code)
	return scanInvite(row)
}

func scanInvite(scanner rowScanner) (*model.Invite, error) {
	var invite model.Invite
	var branchID sql.NullString
	if err := scanner.Scan(
		&invite.ID, &invite.Code, &invite.Role, &branchID, &invite.BranchName,
		&invite.MaxUses, &invite.UsedCount, &invite.ExpiresAt, &invite.Status,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("scan invite: %w", err)
	}
	if branchID.Valid {
		value := branchID.String
		invite.BranchID = &value
	}
	return &invite, nil
}

func (s *Store) RegisterWithInvite(
	ctx context.Context,
	input RegisterInput,
) (*model.User, *model.Family, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("begin registration: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var (
		inviteID, role, familyID string
		branchID                 sql.NullString
		maxUses, used            int
		expiresAt                time.Time
	)
	err = tx.QueryRowContext(ctx, `
		SELECT id, family_id, role, branch_id, max_uses, used_count, expires_at
		FROM family_invites
		WHERE code = ? AND status = 'active'
		  AND expires_at > UTC_TIMESTAMP(6)
		  AND used_count < max_uses
		LIMIT 1
		FOR UPDATE`, input.InviteCode,
	).Scan(&inviteID, &familyID, &role, &branchID, &maxUses, &used, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil, ErrNotFound
	}
	if err != nil {
		return nil, nil, fmt.Errorf("lock invite: %w", err)
	}
	_ = maxUses
	_ = used
	_ = expiresAt

	userID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO users (id, login_name, phone, password_hash, display_name, status)
		VALUES (?, ?, NULLIF(?, ''), ?, ?, 'active')`,
		userID, input.LoginName, input.Phone, input.PasswordHash, input.DisplayName,
	); err != nil {
		if isDuplicateError(err) {
			return nil, nil, ErrConflict
		}
		return nil, nil, fmt.Errorf("insert registered user: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO family_memberships (id, family_id, user_id, role, status)
		VALUES (?, ?, ?, ?, 'active')`,
		uuid.NewString(), familyID, userID, role,
	); err != nil {
		return nil, nil, fmt.Errorf("insert registered membership: %w", err)
	}
	if role == "admin" && branchID.Valid {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO branch_admin_grants
				(id, family_id, branch_id, user_id, include_descendants, status, granted_by_user_id)
			VALUES (?, ?, ?, ?, 1, 'active', ?)`,
			uuid.NewString(), familyID, branchID.String, userID, userID,
		); err != nil {
			return nil, nil, fmt.Errorf("insert invited branch grant: %w", err)
		}
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_invites SET used_count = used_count + 1 WHERE id = ?`,
		inviteID,
	); err != nil {
		return nil, nil, fmt.Errorf("consume invite: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"loginName": input.LoginName, "displayName": input.DisplayName,
		"role": role, "inviteId": inviteID,
	})
	if err := insertAudit(ctx, tx, familyID, userID, "member.registered",
		"user", userID, "", nil, after, AuditMeta{}); err != nil {
		return nil, nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, nil, fmt.Errorf("commit registration: %w", err)
	}

	user := &model.User{
		ID: userID, LoginName: input.LoginName,
		DisplayName: input.DisplayName, Phone: input.Phone, Status: "active",
	}
	family, err := s.GetFamily(ctx, familyID)
	if err != nil {
		return nil, nil, err
	}
	return user, family, nil
}

func randomInviteCode() string {
	const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	bytes := make([]byte, 10)
	if _, err := rand.Read(bytes); err != nil {
		return fmt.Sprintf("INV%s", strings.ToUpper(uuid.NewString()[:8]))
	}
	for index := range bytes {
		bytes[index] = alphabet[int(bytes[index])%len(alphabet)]
	}
	return string(bytes)
}
