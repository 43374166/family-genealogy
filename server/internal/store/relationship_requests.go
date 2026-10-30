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

type RelationshipEndInput struct {
	EdgeType string `json:"edgeType"`
	EdgeID   string `json:"edgeId"`
}

func (s *Store) CreateRelationshipEndRequest(
	ctx context.Context,
	familyID, requesterUserID, edgeType, edgeID string,
) (*model.EditRequest, error) {
	var (
		requestType string
		targetID    string
	)
	switch edgeType {
	case "parent_child":
		requestType = "end_parent_child"
		if err := s.db.QueryRowContext(ctx, `
			SELECT child_id FROM parent_child_relationships
			WHERE family_id = ? AND id = ? AND status = 'active'`,
			familyID, edgeID,
		).Scan(&targetID); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, ErrNotFound
			}
			return nil, fmt.Errorf("lookup parent-child request target: %w", err)
		}
	case "spouse":
		requestType = "end_spouse"
		if err := s.db.QueryRowContext(ctx, `
			SELECT person_a_id FROM spouse_relationships
			WHERE family_id = ? AND id = ?`,
			familyID, edgeID,
		).Scan(&targetID); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, ErrNotFound
			}
			return nil, fmt.Errorf("lookup spouse request target: %w", err)
		}
	default:
		return nil, ErrInvalidRequest
	}
	payload, _ := json.Marshal(RelationshipEndInput{
		EdgeType: edgeType, EdgeID: edgeID,
	})
	requestID := uuid.NewString()
	if _, err := s.db.ExecContext(ctx, `
		INSERT INTO edit_requests
			(id, family_id, requester_user_id, request_type, target_person_id,
			 payload, status)
		VALUES (?, ?, ?, ?, ?, ?, 'pending')`,
		requestID, familyID, requesterUserID, requestType,
		targetID, string(payload),
	); err != nil {
		return nil, fmt.Errorf("insert relationship end request: %w", err)
	}
	return s.GetEditRequest(ctx, familyID, requestID)
}

func deleteParentChildTx(
	ctx context.Context,
	tx *sql.Tx,
	familyID, edgeID string,
) ([]byte, error) {
	var parentID, childID, role string
	err := tx.QueryRowContext(ctx, `
		SELECT parent_id, child_id, parent_role
		FROM parent_child_relationships
		WHERE family_id = ? AND id = ? AND status = 'active'
		LIMIT 1 FOR UPDATE`, familyID, edgeID,
	).Scan(&parentID, &childID, &role)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock parent-child request edge: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		DELETE FROM parent_child_relationships WHERE id = ? AND family_id = ?`,
		edgeID, familyID,
	); err != nil {
		return nil, fmt.Errorf("delete requested parent-child edge: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons SET version = version + 1
		WHERE family_id = ? AND id IN (?, ?)`,
		familyID, parentID, childID,
	); err != nil {
		return nil, fmt.Errorf("touch requested parent-child persons: %w", err)
	}
	before, _ := json.Marshal(map[string]any{
		"id": edgeID, "parentId": parentID, "childId": childID,
		"parentRole": role,
	})
	return before, nil
}

func deleteSpouseTx(
	ctx context.Context,
	tx *sql.Tx,
	familyID, edgeID string,
) ([]byte, error) {
	var personA, personB, status string
	err := tx.QueryRowContext(ctx, `
		SELECT person_a_id, person_b_id, status
		FROM spouse_relationships
		WHERE family_id = ? AND id = ?
		LIMIT 1 FOR UPDATE`, familyID, edgeID,
	).Scan(&personA, &personB, &status)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock spouse request edge: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		DELETE FROM spouse_relationships WHERE id = ? AND family_id = ?`,
		edgeID, familyID,
	); err != nil {
		return nil, fmt.Errorf("delete requested spouse edge: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons SET version = version + 1
		WHERE family_id = ? AND id IN (?, ?)`,
		familyID, personA, personB,
	); err != nil {
		return nil, fmt.Errorf("touch requested spouse persons: %w", err)
	}
	before, _ := json.Marshal(map[string]any{
		"id": edgeID, "personAId": personA, "personBId": personB,
		"status": status,
	})
	return before, nil
}
