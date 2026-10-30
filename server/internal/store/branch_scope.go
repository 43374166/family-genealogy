package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
)

func (s *Store) PersonBranch(ctx context.Context, familyID, personID string) (string, error) {
	var branchID string
	err := s.db.QueryRowContext(ctx, `
		SELECT branch_id FROM persons
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, personID,
	).Scan(&branchID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("lookup person branch: %w", err)
	}
	return branchID, nil
}

func (s *Store) CanAdminAccessBranch(
	ctx context.Context,
	familyID, userID, branchID string,
) (bool, error) {
	if branchID == "" {
		return false, nil
	}
	var count int
	err := s.db.QueryRowContext(ctx, `
		WITH RECURSIVE ancestors (id, parent_branch_id) AS (
			SELECT id, parent_branch_id FROM branches
			WHERE family_id = ? AND id = ?
			UNION ALL
			SELECT b.id, b.parent_branch_id FROM branches b
			JOIN ancestors a ON b.id = a.parent_branch_id
			WHERE b.family_id = ?
		)
		SELECT COUNT(*)
		FROM ancestors a
		JOIN branch_admin_grants g
		  ON g.branch_id = a.id AND g.family_id = ? AND g.user_id = ?
		 AND g.status = 'active'
		WHERE g.include_descendants = 1 OR a.id = g.branch_id`,
		familyID, branchID, familyID, familyID, userID,
	).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("check branch scope: %w", err)
	}
	return count > 0, nil
}

func (s *Store) EditRequestBranches(
	ctx context.Context,
	familyID, requestID string,
) ([]string, error) {
	var (
		requestType string
		targetID    sql.NullString
		payload     []byte
	)
	err := s.db.QueryRowContext(ctx, `
		SELECT request_type, target_person_id, payload
		FROM edit_requests
		WHERE family_id = ? AND id = ?`,
		familyID, requestID,
	).Scan(&requestType, &targetID, &payload)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lookup request branches: %w", err)
	}
	branches := make([]string, 0, 2)
	add := func(branchID string) {
		if branchID == "" {
			return
		}
		for _, existing := range branches {
			if existing == branchID {
				return
			}
		}
		branches = append(branches, branchID)
	}

	switch requestType {
	case "update_person", "update_person_profile":
		if !targetID.Valid {
			return nil, ErrNotFound
		}
		branchID, err := s.PersonBranch(ctx, familyID, targetID.String)
		if err != nil {
			return nil, err
		}
		add(branchID)
	case "create_person":
		var input struct {
			BranchID string `json:"branchId"`
		}
		if err := json.Unmarshal(payload, &input); err != nil {
			return nil, fmt.Errorf("decode create person branch: %w", err)
		}
		add(input.BranchID)
	case "end_parent_child":
		var input struct {
			EdgeID string `json:"edgeId"`
		}
		if err := json.Unmarshal(payload, &input); err != nil {
			return nil, fmt.Errorf("decode parent-child end branch: %w", err)
		}
		branchID, err := s.ParentChildEdgeBranch(ctx, familyID, input.EdgeID)
		if err != nil {
			return nil, err
		}
		add(branchID)
	case "end_spouse":
		var input struct {
			EdgeID string `json:"edgeId"`
		}
		if err := json.Unmarshal(payload, &input); err != nil {
			return nil, fmt.Errorf("decode spouse end branch: %w", err)
		}
		branches, err := s.SpouseEdgeBranches(ctx, familyID, input.EdgeID)
		if err != nil {
			return nil, err
		}
		for _, branchID := range branches {
			add(branchID)
		}
	case "add_parent_child":
		var input struct {
			ChildID string `json:"childId"`
		}
		if err := json.Unmarshal(payload, &input); err != nil {
			return nil, fmt.Errorf("decode parent-child branch: %w", err)
		}
		branchID, err := s.PersonBranch(ctx, familyID, input.ChildID)
		if err != nil {
			return nil, err
		}
		add(branchID)
	case "add_spouse":
		var input struct {
			PersonAID string `json:"personAId"`
			PersonBID string `json:"personBId"`
		}
		if err := json.Unmarshal(payload, &input); err != nil {
			return nil, fmt.Errorf("decode spouse branch: %w", err)
		}
		for _, personID := range []string{input.PersonAID, input.PersonBID} {
			branchID, err := s.PersonBranch(ctx, familyID, personID)
			if err != nil {
				return nil, err
			}
			add(branchID)
		}
	default:
		return nil, ErrInvalidRequest
	}
	return branches, nil
}
