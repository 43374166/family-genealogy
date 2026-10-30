package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"sort"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

func insertPersonTx(ctx context.Context, tx *sql.Tx, familyID string, input NewPerson) (string, []byte, error) {
	var branchExists int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM branches WHERE family_id = ? AND id = ?`,
		familyID, input.BranchID,
	).Scan(&branchExists); err != nil {
		return "", nil, fmt.Errorf("check branch: %w", err)
	}
	if branchExists == 0 {
		return "", nil, ErrNotFound
	}
	personID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO persons
			(id, family_id, branch_id, surname, given_name, courtesy_name, alias,
			 gender, generation_no, birth_order, birth_year, birth_calendar,
			 life_status, biography)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'gregorian', 'living', ?)`,
		personID, familyID, input.BranchID, input.Surname, input.GivenName,
		input.CourtesyName, input.Alias, input.Gender, input.GenerationNo,
		input.BirthOrder, input.BirthYear, input.Biography,
	); err != nil {
		return "", nil, fmt.Errorf("insert person: %w", err)
	}
	after, err := json.Marshal(map[string]any{
		"id":           personID,
		"branchId":     input.BranchID,
		"fullName":     input.Surname + input.GivenName,
		"gender":       input.Gender,
		"generationNo": input.GenerationNo,
		"birthOrder":   input.BirthOrder,
		"birthYear":    input.BirthYear,
	})
	if err != nil {
		return "", nil, fmt.Errorf("encode person audit: %w", err)
	}
	return personID, after, nil
}

func addParentChildTx(
	ctx context.Context,
	tx *sql.Tx,
	familyID string,
	input ParentChildInput,
) (*model.ParentChildEdge, []byte, error) {
	if input.ParentID == input.ChildID {
		return nil, nil, ErrInvalidRelationship
	}
	people, err := lockPeople(ctx, tx, familyID, input.ParentID, input.ChildID)
	if err != nil {
		return nil, nil, err
	}
	parent := people[input.ParentID]
	child := people[input.ChildID]
	if parent == nil || child == nil {
		return nil, nil, ErrNotFound
	}
	if parent.GenerationNo >= child.GenerationNo {
		return nil, nil, ErrInvalidRelationship
	}
	var duplicate int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM parent_child_relationships
		WHERE family_id = ? AND parent_id = ? AND child_id = ? AND status = 'active'`,
		familyID, input.ParentID, input.ChildID,
	).Scan(&duplicate); err != nil {
		return nil, nil, fmt.Errorf("check parent-child duplicate: %w", err)
	}
	if duplicate > 0 {
		return nil, nil, ErrConflict
	}
	var roleTaken int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM parent_child_relationships
		WHERE family_id = ? AND child_id = ? AND parent_role = ? AND status = 'active'`,
		familyID, input.ChildID, input.ParentRole,
	).Scan(&roleTaken); err != nil {
		return nil, nil, fmt.Errorf("check parent role: %w", err)
	}
	if roleTaken > 0 {
		return nil, nil, ErrConflict
	}
	edgeID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO parent_child_relationships
			(id, family_id, parent_id, child_id, parent_role, status)
		VALUES (?, ?, ?, ?, ?, 'active')`,
		edgeID, familyID, input.ParentID, input.ChildID, input.ParentRole,
	); err != nil {
		if isDuplicateError(err) {
			return nil, nil, ErrConflict
		}
		if isCycleError(err) {
			return nil, nil, ErrCycle
		}
		return nil, nil, fmt.Errorf("insert parent-child: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons SET version = version + 1
		WHERE family_id = ? AND id IN (?, ?)`,
		familyID, input.ParentID, input.ChildID,
	); err != nil {
		return nil, nil, fmt.Errorf("touch parent-child persons: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"parentId":   input.ParentID,
		"childId":    input.ChildID,
		"parentRole": input.ParentRole,
	})
	return &model.ParentChildEdge{
		ID: edgeID, ParentID: input.ParentID, ChildID: input.ChildID,
		ParentRole: input.ParentRole, Status: "active",
	}, after, nil
}

func addSpouseTx(
	ctx context.Context,
	tx *sql.Tx,
	familyID string,
	input SpouseInput,
) (*model.SpouseEdge, []byte, error) {
	if input.PersonAID == input.PersonBID {
		return nil, nil, ErrInvalidRelationship
	}
	people, err := lockPeople(ctx, tx, familyID, input.PersonAID, input.PersonBID)
	if err != nil {
		return nil, nil, err
	}
	a := people[input.PersonAID]
	b := people[input.PersonBID]
	if a == nil || b == nil {
		return nil, nil, ErrNotFound
	}
	if a.GenerationNo != b.GenerationNo {
		return nil, nil, ErrInvalidRelationship
	}
	ids := []string{input.PersonAID, input.PersonBID}
	sort.Strings(ids)
	var duplicate int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM spouse_relationships
		WHERE family_id = ? AND person_a_id = ? AND person_b_id = ?`,
		familyID, ids[0], ids[1],
	).Scan(&duplicate); err != nil {
		return nil, nil, fmt.Errorf("check spouse duplicate: %w", err)
	}
	if duplicate > 0 {
		return nil, nil, ErrConflict
	}
	edgeID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO spouse_relationships
			(id, family_id, person_a_id, person_b_id, status)
		VALUES (?, ?, ?, ?, 'married')`,
		edgeID, familyID, ids[0], ids[1],
	); err != nil {
		if isDuplicateError(err) {
			return nil, nil, ErrConflict
		}
		return nil, nil, fmt.Errorf("insert spouse: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons SET version = version + 1
		WHERE family_id = ? AND id IN (?, ?)`,
		familyID, ids[0], ids[1],
	); err != nil {
		return nil, nil, fmt.Errorf("touch spouse persons: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"personAId": ids[0],
		"personBId": ids[1],
		"status":    "married",
	})
	return &model.SpouseEdge{
		ID: edgeID, PersonAID: ids[0], PersonBID: ids[1], Status: "married",
	}, after, nil
}
