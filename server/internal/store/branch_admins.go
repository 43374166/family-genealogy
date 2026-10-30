package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

func (s *Store) ListFamilyAccounts(
	ctx context.Context,
	familyID string,
) ([]model.FamilyAccount, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT m.user_id, u.login_name, u.display_name, m.role,
		       COALESCE(p.full_name, '')
		FROM family_memberships m
		JOIN users u ON u.id = m.user_id
		LEFT JOIN persons p ON p.id = m.person_id AND p.family_id = m.family_id
		WHERE m.family_id = ? AND m.status = 'active'
		ORDER BY m.role = 'owner' DESC, u.display_name, m.user_id
		LIMIT 200`, familyID)
	if err != nil {
		return nil, fmt.Errorf("list family accounts: %w", err)
	}
	defer rows.Close()
	items := make([]model.FamilyAccount, 0)
	for rows.Next() {
		var item model.FamilyAccount
		if err := rows.Scan(
			&item.UserID, &item.LoginName, &item.DisplayName,
			&item.Role, &item.PersonName,
		); err != nil {
			return nil, fmt.Errorf("scan family account: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate family accounts: %w", err)
	}
	return items, nil
}

func (s *Store) ListBranchAdminGrants(
	ctx context.Context,
	familyID string,
) ([]model.BranchAdminGrant, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT g.id, g.user_id, u.display_name, u.login_name,
		       g.branch_id, b.name, g.include_descendants, g.status, g.created_at
		FROM branch_admin_grants g
		JOIN users u ON u.id = g.user_id
		JOIN family_memberships m
		  ON m.family_id = g.family_id AND m.user_id = g.user_id
		 AND m.status = 'active' AND m.role <> 'owner'
		JOIN branches b ON b.id = g.branch_id AND b.family_id = g.family_id
		WHERE g.family_id = ? AND g.status = 'active'
		ORDER BY b.name, u.display_name, g.created_at
		LIMIT 200`, familyID)
	if err != nil {
		return nil, fmt.Errorf("list branch admin grants: %w", err)
	}
	defer rows.Close()
	items := make([]model.BranchAdminGrant, 0)
	for rows.Next() {
		var item model.BranchAdminGrant
		if err := rows.Scan(
			&item.ID, &item.UserID, &item.DisplayName, &item.LoginName,
			&item.BranchID, &item.BranchName, &item.IncludeDescendants,
			&item.Status, &item.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan branch admin grant: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate branch admin grants: %w", err)
	}
	return items, nil
}

func (s *Store) GrantBranchAdmin(
	ctx context.Context,
	familyID, actorUserID, targetUserID, branchID string,
	includeDescendants bool,
	meta AuditMeta,
) (*model.BranchAdminGrant, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin branch grant: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var role string
	err = tx.QueryRowContext(ctx, `
		SELECT role FROM family_memberships
		WHERE family_id = ? AND user_id = ? AND status = 'active'
		LIMIT 1 FOR UPDATE`, familyID, targetUserID,
	).Scan(&role)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock target membership: %w", err)
	}
	if role == "owner" {
		return nil, ErrForbidden
	}
	var branchExists int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM branches WHERE family_id = ? AND id = ?`,
		familyID, branchID,
	).Scan(&branchExists); err != nil {
		return nil, fmt.Errorf("check grant branch: %w", err)
	}
	if branchExists == 0 {
		return nil, ErrNotFound
	}
	grantID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO branch_admin_grants
			(id, family_id, branch_id, user_id, include_descendants, status,
			 granted_by_user_id)
		VALUES (?, ?, ?, ?, ?, 'active', ?)
		ON DUPLICATE KEY UPDATE
			status = 'active',
			include_descendants = VALUES(include_descendants),
			granted_by_user_id = VALUES(granted_by_user_id),
			created_at = UTC_TIMESTAMP(6)`,
		grantID, familyID, branchID, targetUserID, includeDescendants, actorUserID,
	); err != nil {
		return nil, fmt.Errorf("save branch grant: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_memberships SET role = 'admin'
		WHERE family_id = ? AND user_id = ? AND status = 'active'`,
		familyID, targetUserID,
	); err != nil {
		return nil, fmt.Errorf("promote branch admin: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"userId": targetUserID, "branchId": branchID,
		"includeDescendants": includeDescendants,
	})
	if err := insertAudit(ctx, tx, familyID, actorUserID, "branch_admin.granted",
		"branch_admin_grant", grantID, "", nil, after, meta); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit branch grant: %w", err)
	}
	return s.getBranchAdminGrant(ctx, familyID, targetUserID, branchID)
}

func (s *Store) RevokeBranchAdmin(
	ctx context.Context,
	familyID, actorUserID, grantID string,
	meta AuditMeta,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin branch revoke: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var targetUserID, status, targetRole string
	err = tx.QueryRowContext(ctx, `
		SELECT g.user_id, g.status, m.role
		FROM branch_admin_grants g
		JOIN family_memberships m
		  ON m.family_id = g.family_id AND m.user_id = g.user_id
		 AND m.status = 'active'
		WHERE g.family_id = ? AND g.id = ?
		LIMIT 1 FOR UPDATE`, familyID, grantID,
	).Scan(&targetUserID, &status, &targetRole)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("lock branch grant: %w", err)
	}
	if status != "active" {
		return ErrNotFound
	}
	if targetRole == "owner" {
		return ErrForbidden
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE branch_admin_grants SET status = 'revoked'
		WHERE id = ? AND family_id = ?`, grantID, familyID,
	); err != nil {
		return fmt.Errorf("revoke branch grant: %w", err)
	}
	var remaining int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM branch_admin_grants
		WHERE family_id = ? AND user_id = ? AND status = 'active'`,
		familyID, targetUserID,
	).Scan(&remaining); err != nil {
		return fmt.Errorf("count remaining grants: %w", err)
	}
	if remaining == 0 {
		if _, err := tx.ExecContext(ctx, `
			UPDATE family_memberships SET role = 'member'
			WHERE family_id = ? AND user_id = ? AND status = 'active'
			  AND role = 'admin'`,
			familyID, targetUserID,
		); err != nil {
			return fmt.Errorf("demote branch admin: %w", err)
		}
	}
	after, _ := json.Marshal(map[string]any{"status": "revoked"})
	if err := insertAudit(ctx, tx, familyID, actorUserID, "branch_admin.revoked",
		"branch_admin_grant", grantID, "", nil, after, meta); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit branch revoke: %w", err)
	}
	return nil
}

func (s *Store) getBranchAdminGrant(
	ctx context.Context,
	familyID, targetUserID, branchID string,
) (*model.BranchAdminGrant, error) {
	var item model.BranchAdminGrant
	err := s.db.QueryRowContext(ctx, `
		SELECT g.id, g.user_id, u.display_name, u.login_name,
		       g.branch_id, b.name, g.include_descendants, g.status, g.created_at
		FROM branch_admin_grants g
		JOIN users u ON u.id = g.user_id
		JOIN branches b ON b.id = g.branch_id AND b.family_id = g.family_id
		WHERE g.family_id = ? AND g.user_id = ? AND g.branch_id = ?
		LIMIT 1`, familyID, targetUserID, branchID,
	).Scan(
		&item.ID, &item.UserID, &item.DisplayName, &item.LoginName,
		&item.BranchID, &item.BranchName, &item.IncludeDescendants,
		&item.Status, &item.CreatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get branch admin grant: %w", err)
	}
	return &item, nil
}
