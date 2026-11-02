package store

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
)

// shiftGenerationComponent moves every person connected to personID through
// parent-child or spouse links by delta. Editing one member's generation then
// keeps parents, siblings, spouses and children consistent instead of failing
// the per-person generation checks.
func shiftGenerationComponent(
	ctx context.Context, tx *sql.Tx, familyID, personID string, delta int,
) error {
	if delta == 0 {
		return nil
	}
	seen := map[string]bool{personID: true}
	queue := []string{personID}
	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		rows, err := tx.QueryContext(ctx, `
			SELECT parent_id FROM parent_child_relationships
			WHERE family_id = ? AND child_id = ? AND status = 'active'
			UNION
			SELECT child_id FROM parent_child_relationships
			WHERE family_id = ? AND parent_id = ? AND status = 'active'
			UNION
			SELECT CASE WHEN person_a_id = ? THEN person_b_id ELSE person_a_id END
			FROM spouse_relationships
			WHERE family_id = ? AND (person_a_id = ? OR person_b_id = ?)
			  AND status = 'active'`,
			familyID, current, familyID, current,
			current, familyID, current, current)
		if err != nil {
			return fmt.Errorf("walk generation component: %w", err)
		}
		for rows.Next() {
			var id string
			if err := rows.Scan(&id); err != nil {
				rows.Close()
				return fmt.Errorf("scan generation component: %w", err)
			}
			if id != "" && !seen[id] {
				seen[id] = true
				queue = append(queue, id)
			}
		}
		if err := rows.Err(); err != nil {
			rows.Close()
			return fmt.Errorf("iterate generation component: %w", err)
		}
		rows.Close()
	}
	if len(seen) > 500 {
		return fmt.Errorf("%w: family component is too large", ErrInvalidRelationship)
	}
	ids := make([]string, 0, len(seen))
	for id := range seen {
		ids = append(ids, id)
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(ids)), ",")
	args := make([]any, 0, len(ids)+2)
	for _, id := range ids {
		args = append(args, id)
	}
	args = append(args, familyID)
	var invalid int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM persons
		WHERE id IN (`+placeholders+`) AND family_id = ?
		  AND (generation_no + ? < 1 OR generation_no + ? > 99)`,
		append(args, delta, delta)...,
	).Scan(&invalid); err != nil {
		return fmt.Errorf("validate shifted generations: %w", err)
	}
	if invalid > 0 {
		return fmt.Errorf("%w: shifted generation is out of range", ErrInvalidRelationship)
	}
	updateArgs := make([]any, 0, len(ids)+2)
	updateArgs = append(updateArgs, delta)
	for _, id := range ids {
		updateArgs = append(updateArgs, id)
	}
	updateArgs = append(updateArgs, familyID)
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons SET generation_no = generation_no + ?
		WHERE id IN (`+placeholders+`) AND family_id = ?`,
		updateArgs...,
	); err != nil {
		return fmt.Errorf("shift generation component: %w", err)
	}
	return nil
}
