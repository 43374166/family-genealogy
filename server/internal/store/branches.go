package store

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/43374166/family-genealogy/server/internal/model"
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
