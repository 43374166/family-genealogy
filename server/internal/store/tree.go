package store

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/43374166/family-genealogy/server/internal/model"
)

func (s *Store) GetTree(ctx context.Context, familyID string, generation int, branchID string) (*model.Tree, error) {
	family, err := s.GetFamily(ctx, familyID)
	if err != nil {
		return nil, err
	}

	query := `SELECT ` + personSummaryColumns + `
		FROM persons p
		WHERE p.family_id = ? AND p.status = 'active'`
	args := []any{familyID}
	if generation > 0 {
		query += ` AND p.generation_no = ?`
		args = append(args, generation)
	}
	if branchID != "" {
		query += ` AND p.branch_id = ?`
		args = append(args, branchID)
	}
	query += ` ORDER BY p.generation_no ASC, p.birth_order IS NULL, p.birth_order ASC, p.birth_year IS NULL, p.birth_year ASC, p.id ASC`

	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("tree persons: %w", err)
	}
	defer rows.Close()

	persons := make([]model.PersonSummary, 0)
	personIDs := make(map[string]struct{})
	for rows.Next() {
		person, err := scanPersonSummary(rows)
		if err != nil {
			return nil, fmt.Errorf("scan tree person: %w", err)
		}
		persons = append(persons, *person)
		personIDs[person.ID] = struct{}{}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate tree persons: %w", err)
	}

	parentChild, err := s.treeParentChild(ctx, familyID, personIDs)
	if err != nil {
		return nil, err
	}
	spouses, err := s.treeSpouses(ctx, familyID, personIDs)
	if err != nil {
		return nil, err
	}

	return &model.Tree{
		FamilyID:    familyID,
		Version:     family.Version,
		Persons:     persons,
		ParentChild: parentChild,
		Spouses:     spouses,
	}, nil
}

func (s *Store) treeParentChild(ctx context.Context, familyID string, personIDs map[string]struct{}) ([]model.ParentChildEdge, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, parent_id, child_id, parent_role, status
		FROM parent_child_relationships
		WHERE family_id = ? AND status = 'active'
		ORDER BY id ASC`, familyID)
	if err != nil {
		return nil, fmt.Errorf("tree parent-child: %w", err)
	}
	defer rows.Close()

	edges := make([]model.ParentChildEdge, 0)
	for rows.Next() {
		var edge model.ParentChildEdge
		if err := rows.Scan(&edge.ID, &edge.ParentID, &edge.ChildID, &edge.ParentRole, &edge.Status); err != nil {
			return nil, fmt.Errorf("scan parent-child edge: %w", err)
		}
		if _, ok := personIDs[edge.ParentID]; !ok {
			continue
		}
		if _, ok := personIDs[edge.ChildID]; !ok {
			continue
		}
		edges = append(edges, edge)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate parent-child edges: %w", err)
	}
	return edges, nil
}

func (s *Store) treeSpouses(ctx context.Context, familyID string, personIDs map[string]struct{}) ([]model.SpouseEdge, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, person_a_id, person_b_id, status, start_year, end_year
		FROM spouse_relationships
		WHERE family_id = ?
		ORDER BY id ASC`, familyID)
	if err != nil {
		return nil, fmt.Errorf("tree spouses: %w", err)
	}
	defer rows.Close()

	edges := make([]model.SpouseEdge, 0)
	for rows.Next() {
		var edge model.SpouseEdge
		var startYear, endYear sql.NullInt64
		if err := rows.Scan(&edge.ID, &edge.PersonAID, &edge.PersonBID, &edge.Status, &startYear, &endYear); err != nil {
			return nil, fmt.Errorf("scan spouse edge: %w", err)
		}
		if _, ok := personIDs[edge.PersonAID]; !ok {
			continue
		}
		if _, ok := personIDs[edge.PersonBID]; !ok {
			continue
		}
		if startYear.Valid {
			v := int(startYear.Int64)
			edge.StartYear = &v
		}
		if endYear.Valid {
			v := int(endYear.Int64)
			edge.EndYear = &v
		}
		edges = append(edges, edge)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate spouse edges: %w", err)
	}
	return edges, nil
}
