package store

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

func (s *Store) ListGenerationNames(
	ctx context.Context, familyID string,
) ([]model.GenerationName, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT generation_no, name
		FROM family_generation_names
		WHERE family_id = ?
		ORDER BY generation_no`, familyID)
	if err != nil {
		return nil, fmt.Errorf("list generation names: %w", err)
	}
	defer rows.Close()
	items := make([]model.GenerationName, 0)
	for rows.Next() {
		var item model.GenerationName
		if err := rows.Scan(&item.GenerationNo, &item.Name); err != nil {
			return nil, fmt.Errorf("scan generation name: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate generation names: %w", err)
	}
	return items, nil
}

func (s *Store) GenerationPoem(
	ctx context.Context, familyID string,
) (string, error) {
	var poem string
	if err := s.db.QueryRowContext(ctx, `
		SELECT generation_poem FROM families WHERE id = ?`, familyID,
	).Scan(&poem); err != nil {
		return "", fmt.Errorf("load generation poem: %w", err)
	}
	return poem, nil
}

func (s *Store) ReplaceGenerationNames(
	ctx context.Context, familyID, actorUserID string,
	items []model.GenerationName, poem string, meta AuditMeta,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin generation names: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var beforeJSON []byte
	_ = tx.QueryRowContext(ctx, `
		SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT(
			'generationNo', generation_no, 'name', name
		)), JSON_ARRAY())
		FROM family_generation_names WHERE family_id = ?`, familyID,
	).Scan(&beforeJSON)

	if _, err := tx.ExecContext(ctx,
		`DELETE FROM family_generation_names WHERE family_id = ?`, familyID,
	); err != nil {
		return fmt.Errorf("clear generation names: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE families SET generation_poem = ? WHERE id = ?`,
		poem, familyID,
	); err != nil {
		return fmt.Errorf("save generation poem: %w", err)
	}
	for _, item := range items {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO family_generation_names
				(id, family_id, generation_no, name)
			VALUES (?, ?, ?, ?)`,
			uuid.NewString(), familyID, item.GenerationNo, item.Name,
		); err != nil {
			return fmt.Errorf("insert generation name: %w", err)
		}
	}
	after, _ := json.Marshal(map[string]any{"items": items, "poem": poem})
	if err := insertAudit(ctx, tx, familyID, actorUserID,
		"family.generation_names_updated", "family", familyID,
		"", beforeJSON, after, meta,
	); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit generation names: %w", err)
	}
	return nil
}
