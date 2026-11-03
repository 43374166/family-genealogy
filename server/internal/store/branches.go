package store

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

func (s *Store) ListBranches(ctx context.Context, familyID string) ([]model.Branch, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, parent_branch_id, name, sort_order
		FROM branches
		WHERE family_id = ?
		ORDER BY sort_order ASC, name ASC`, familyID)
	if err != nil {
		return nil, fmt.Errorf("list branches: %w", err)
	}
	defer rows.Close()

	branches := make([]model.Branch, 0)
	for rows.Next() {
		var branch model.Branch
		var parentID sql.NullString
		if err := rows.Scan(&branch.ID, &parentID, &branch.Name, &branch.SortOrder); err != nil {
			return nil, fmt.Errorf("scan branch: %w", err)
		}
		if parentID.Valid {
			value := parentID.String
			branch.ParentID = &value
		}
		branches = append(branches, branch)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate branches: %w", err)
	}
	return branches, nil
}

func (s *Store) CreateBranch(
	ctx context.Context,
	familyID, actorUserID, name string,
	sortOrder int,
	meta AuditMeta,
) (*model.Branch, error) {
	branchID := uuid.NewString()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin branch creation: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO branches (id, family_id, name, sort_order)
		VALUES (?, ?, ?, ?)`, branchID, familyID, name, sortOrder); err != nil {
		return nil, fmt.Errorf("create branch: %w", err)
	}
	after := []byte(fmt.Sprintf(`{"name":%q,"sortOrder":%d}`, name, sortOrder))
	if err := insertAudit(ctx, tx, familyID, actorUserID, "branch.created",
		"branch", branchID, "", nil, after, meta); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit branch creation: %w", err)
	}
	return &model.Branch{ID: branchID, Name: name, SortOrder: sortOrder}, nil
}

func (s *Store) DeleteBranch(
	ctx context.Context,
	familyID, actorUserID, branchID string,
	meta AuditMeta,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin branch deletion: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	var personCount int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM persons
		WHERE family_id = ? AND branch_id = ? AND status = 'active'`,
		familyID, branchID).Scan(&personCount); err != nil {
		return fmt.Errorf("count branch persons: %w", err)
	}
	if personCount > 0 {
		return ErrConflict
	}
	if _, err := tx.ExecContext(ctx, `
		DELETE FROM branch_admin_grants WHERE family_id = ? AND branch_id = ?`,
		familyID, branchID); err != nil {
		return fmt.Errorf("delete branch grants: %w", err)
	}
	result, err := tx.ExecContext(ctx, `
		DELETE FROM branches WHERE id = ? AND family_id = ?`, branchID, familyID)
	if err != nil {
		return fmt.Errorf("delete branch: %w", err)
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("read branch delete rows: %w", err)
	}
	if affected == 0 {
		return ErrNotFound
	}
	if err := insertAudit(ctx, tx, familyID, actorUserID, "branch.deleted",
		"branch", branchID, "", nil, nil, meta); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit branch deletion: %w", err)
	}
	return nil
}

func (s *Store) UpdateBranch(
	ctx context.Context,
	familyID, actorUserID, branchID, name string,
	sortOrder int,
	meta AuditMeta,
) (*model.Branch, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin branch update: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	result, err := tx.ExecContext(ctx, `
		UPDATE branches SET name = ?, sort_order = ?
		WHERE id = ? AND family_id = ?`, name, sortOrder, branchID, familyID)
	if err != nil {
		return nil, fmt.Errorf("update branch: %w", err)
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return nil, fmt.Errorf("read branch update rows: %w", err)
	}
	if affected == 0 {
		return nil, ErrNotFound
	}
	after := []byte(fmt.Sprintf(`{"name":%q,"sortOrder":%d}`, name, sortOrder))
	if err := insertAudit(ctx, tx, familyID, actorUserID, "branch.updated",
		"branch", branchID, "", nil, after, meta); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit branch update: %w", err)
	}
	return &model.Branch{ID: branchID, Name: name, SortOrder: sortOrder}, nil
}
