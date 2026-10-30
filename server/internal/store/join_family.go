package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

func (s *Store) JoinFamilyWithInvite(
	ctx context.Context,
	userID, inviteCode string,
	meta AuditMeta,
) (*model.Membership, *model.Family, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("begin family join: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var (
		inviteID, familyID, role string
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
		LIMIT 1 FOR UPDATE`, inviteCode,
	).Scan(&inviteID, &familyID, &role, &branchID, &maxUses, &used, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil, ErrNotFound
	}
	if err != nil {
		return nil, nil, fmt.Errorf("lock family invite: %w", err)
	}
	_ = maxUses
	_ = used
	_ = expiresAt

	var existing int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM family_memberships
		WHERE family_id = ? AND user_id = ?`,
		familyID, userID,
	).Scan(&existing); err != nil {
		return nil, nil, fmt.Errorf("check existing membership: %w", err)
	}
	if existing > 0 {
		return nil, nil, ErrConflict
	}
	membershipID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO family_memberships
			(id, family_id, user_id, role, status)
		VALUES (?, ?, ?, ?, 'active')`,
		membershipID, familyID, userID, role,
	); err != nil {
		return nil, nil, fmt.Errorf("insert joined membership: %w", err)
	}
	if role == "admin" && branchID.Valid {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO branch_admin_grants
				(id, family_id, branch_id, user_id, include_descendants, status, granted_by_user_id)
			VALUES (?, ?, ?, ?, 1, 'active', NULL)`,
			uuid.NewString(), familyID, branchID.String, userID,
		); err != nil {
			return nil, nil, fmt.Errorf("insert joined branch grant: %w", err)
		}
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_invites SET used_count = used_count + 1 WHERE id = ?`,
		inviteID,
	); err != nil {
		return nil, nil, fmt.Errorf("consume family invite: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"userId": userID, "role": role, "inviteId": inviteID,
	})
	if err := insertAudit(ctx, tx, familyID, userID, "member.joined",
		"user", userID, "", nil, after, meta); err != nil {
		return nil, nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, nil, fmt.Errorf("commit family join: %w", err)
	}
	membership, family, err := s.GetMembership(ctx, userID, familyID)
	if err != nil {
		return nil, nil, err
	}
	return membership, family, nil
}
