package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/43374166/family-genealogy/server/internal/model"
)

type UpdatePersonInput struct {
	Surname      string `json:"surname"`
	GivenName    string `json:"givenName"`
	CourtesyName string `json:"courtesyName"`
	Alias        string `json:"alias"`
	Gender       string `json:"gender"`
	GenerationNo int    `json:"generationNo"`
	BranchID     string `json:"branchId"`
	BirthOrder   *int   `json:"birthOrder"`
	BirthYear    *int   `json:"birthYear"`
	DeathYear    *int   `json:"deathYear"`
	LifeStatus   string `json:"lifeStatus"`
	BirthPlace   string `json:"birthPlace"`
	Residence    string `json:"residence"`
	Occupation   string `json:"occupation"`
	Education    string `json:"education"`
	Biography    string `json:"biography"`
	Version      int    `json:"version"`
}

func (s *Store) UpdatePerson(
	ctx context.Context,
	familyID, actorUserID, personID string,
	input UpdatePersonInput,
	meta AuditMeta,
) (*model.Person, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin person edit: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var version int
	var beforeData []byte
	err = tx.QueryRowContext(ctx, `
		SELECT version, JSON_OBJECT(
			'fullName', full_name, 'surname', surname, 'givenName', given_name,
			'courtesyName', courtesy_name, 'alias', alias, 'gender', gender,
			'generationNo', generation_no, 'branchId', branch_id,
			'birthOrder', birth_order, 'birthYear', birth_year,
			'deathYear', death_year, 'lifeStatus', life_status,
			'birthPlace', birth_place, 'residence', residence,
			'occupation', occupation, 'education', education,
			'biography', biography
		)
		FROM persons
		WHERE family_id = ? AND id = ? AND status = 'active'
		LIMIT 1 FOR UPDATE`, familyID, personID,
	).Scan(&version, &beforeData)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock person edit: %w", err)
	}
	if version != input.Version {
		return nil, ErrVersionConflict
	}
	var branchExists int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM branches WHERE family_id = ? AND id = ?`,
		familyID, input.BranchID,
	).Scan(&branchExists); err != nil {
		return nil, fmt.Errorf("check edit branch: %w", err)
	}
	if branchExists == 0 {
		return nil, ErrNotFound
	}

	// Changing a generation must keep parent/child and spouse generations valid.
	var maxParent, minChild, badSpouses int
	if err := tx.QueryRowContext(ctx, `
		SELECT COALESCE(MAX(p.generation_no), 0)
		FROM parent_child_relationships pc
		JOIN persons p ON p.id = pc.parent_id AND p.family_id = pc.family_id
		WHERE pc.family_id = ? AND pc.child_id = ? AND pc.status = 'active'`,
		familyID, personID,
	).Scan(&maxParent); err != nil {
		return nil, fmt.Errorf("check parent generations: %w", err)
	}
	if err := tx.QueryRowContext(ctx, `
		SELECT COALESCE(MIN(p.generation_no), 0)
		FROM parent_child_relationships pc
		JOIN persons p ON p.id = pc.child_id AND p.family_id = pc.family_id
		WHERE pc.family_id = ? AND pc.parent_id = ? AND pc.status = 'active'`,
		familyID, personID,
	).Scan(&minChild); err != nil {
		return nil, fmt.Errorf("check child generations: %w", err)
	}
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM spouse_relationships s
		JOIN persons p ON p.family_id = s.family_id
		 AND p.id = CASE WHEN s.person_a_id = ? THEN s.person_b_id ELSE s.person_a_id END
		WHERE s.family_id = ? AND (s.person_a_id = ? OR s.person_b_id = ?)
		  AND p.generation_no <> ?`,
		personID, familyID, personID, personID, input.GenerationNo,
	).Scan(&badSpouses); err != nil {
		return nil, fmt.Errorf("check spouse generations: %w", err)
	}
	if maxParent >= input.GenerationNo || (minChild > 0 && minChild <= input.GenerationNo) || badSpouses > 0 {
		return nil, ErrInvalidRelationship
	}

	var birthMonth, birthDay, deathMonth, deathDay sql.NullInt64
	if input.BirthYear != nil {
		_ = tx.QueryRowContext(ctx, `
			SELECT birth_month, birth_day FROM persons WHERE id = ?`, personID,
		).Scan(&birthMonth, &birthDay)
	}
	if input.DeathYear != nil {
		_ = tx.QueryRowContext(ctx, `
			SELECT death_month, death_day FROM persons WHERE id = ?`, personID,
		).Scan(&deathMonth, &deathDay)
	}
	if input.LifeStatus != "deceased" {
		input.DeathYear = nil
		deathMonth, deathDay = sql.NullInt64{}, sql.NullInt64{}
	}
	var birthOrder any
	if input.BirthOrder != nil {
		birthOrder = *input.BirthOrder
	}
	var birthYear, deathYear any
	if input.BirthYear != nil {
		birthYear = *input.BirthYear
	}
	if input.DeathYear != nil {
		deathYear = *input.DeathYear
	}
	birthCalendar := "unknown"
	birthText := ""
	if input.BirthYear != nil {
		birthCalendar = "gregorian"
	}
	deathCalendar := "unknown"
	deathText := ""
	if input.DeathYear != nil {
		deathCalendar = "gregorian"
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE persons
		SET surname = ?, given_name = ?, courtesy_name = ?, alias = ?,
		    gender = ?, generation_no = ?, branch_id = ?, birth_order = ?,
		    birth_year = ?, birth_month = ?, birth_day = ?,
		    birth_calendar = ?, birth_date_text = ?,
		    death_year = ?, death_month = ?, death_day = ?,
		    death_calendar = ?, death_date_text = ?,
		    life_status = ?, birth_place = ?, residence = ?, occupation = ?,
		    education = ?, biography = ?, version = version + 1
		WHERE id = ? AND family_id = ? AND version = ?`,
		input.Surname, input.GivenName, input.CourtesyName, input.Alias,
		input.Gender, input.GenerationNo, input.BranchID, birthOrder,
		birthYear, birthMonth, birthDay, birthCalendar, birthText,
		deathYear, deathMonth, deathDay, deathCalendar, deathText,
		input.LifeStatus, input.BirthPlace, input.Residence, input.Occupation,
		input.Education, input.Biography, personID, familyID, input.Version,
	); err != nil {
		return nil, fmt.Errorf("update person: %w", err)
	}

	afterData, _ := json.Marshal(map[string]any{
		"fullName": input.Surname + input.GivenName,
		"gender":   input.Gender, "generationNo": input.GenerationNo,
		"branchId": input.BranchID, "birthYear": input.BirthYear,
		"deathYear": input.DeathYear, "lifeStatus": input.LifeStatus,
		"birthPlace": input.BirthPlace, "residence": input.Residence,
		"occupation": input.Occupation, "education": input.Education,
		"biography": input.Biography, "version": input.Version + 1,
	})
	if err := insertAudit(ctx, tx, familyID, actorUserID, "person.updated",
		"person", personID, "", beforeData, afterData, meta); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit person edit: %w", err)
	}
	return s.GetPerson(ctx, familyID, personID)
}

func (s *Store) ParentChildEdgeBranch(
	ctx context.Context,
	familyID, edgeID string,
) (string, error) {
	var branchID string
	err := s.db.QueryRowContext(ctx, `
		SELECT p.branch_id
		FROM parent_child_relationships pc
		JOIN persons p ON p.id = pc.child_id AND p.family_id = pc.family_id
		WHERE pc.family_id = ? AND pc.id = ? AND pc.status = 'active'`,
		familyID, edgeID,
	).Scan(&branchID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("lookup parent-child branch: %w", err)
	}
	return branchID, nil
}

func (s *Store) SpouseEdgeBranches(
	ctx context.Context,
	familyID, edgeID string,
) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT p.branch_id
		FROM spouse_relationships s
		JOIN persons p ON p.family_id = s.family_id
		 AND p.id IN (s.person_a_id, s.person_b_id)
		WHERE s.family_id = ? AND s.id = ?`,
		familyID, edgeID,
	)
	if err != nil {
		return nil, fmt.Errorf("lookup spouse branches: %w", err)
	}
	defer rows.Close()
	branches := make([]string, 0, 2)
	for rows.Next() {
		var branchID string
		if err := rows.Scan(&branchID); err != nil {
			return nil, fmt.Errorf("scan spouse branch: %w", err)
		}
		branches = append(branches, branchID)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate spouse branches: %w", err)
	}
	if len(branches) == 0 {
		return nil, ErrNotFound
	}
	return branches, nil
}

func (s *Store) DeleteParentChild(
	ctx context.Context,
	familyID, actorUserID, edgeID string,
	meta AuditMeta,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin relationship delete: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var parentID, childID, role string
	err = tx.QueryRowContext(ctx, `
		SELECT parent_id, child_id, parent_role
		FROM parent_child_relationships
		WHERE family_id = ? AND id = ? AND status = 'active'
		LIMIT 1 FOR UPDATE`, familyID, edgeID,
	).Scan(&parentID, &childID, &role)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("lock parent-child edge: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		DELETE FROM parent_child_relationships WHERE id = ? AND family_id = ?`,
		edgeID, familyID,
	); err != nil {
		return fmt.Errorf("delete parent-child edge: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons SET version = version + 1
		WHERE family_id = ? AND id IN (?, ?)`,
		familyID, parentID, childID,
	); err != nil {
		return fmt.Errorf("touch relationship persons: %w", err)
	}
	before, _ := json.Marshal(map[string]any{
		"id": edgeID, "parentId": parentID, "childId": childID,
		"parentRole": role,
	})
	if err := insertAudit(ctx, tx, familyID, actorUserID, "relationship.deleted",
		"parent_child_relationship", edgeID, "", before, nil, meta); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit relationship delete: %w", err)
	}
	return nil
}

func (s *Store) DeleteSpouse(
	ctx context.Context,
	familyID, actorUserID, edgeID string,
	meta AuditMeta,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin spouse delete: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var personA, personB, status string
	err = tx.QueryRowContext(ctx, `
		SELECT person_a_id, person_b_id, status
		FROM spouse_relationships
		WHERE family_id = ? AND id = ?
		LIMIT 1 FOR UPDATE`, familyID, edgeID,
	).Scan(&personA, &personB, &status)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("lock spouse edge: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		DELETE FROM spouse_relationships WHERE id = ? AND family_id = ?`,
		edgeID, familyID,
	); err != nil {
		return fmt.Errorf("delete spouse edge: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons SET version = version + 1
		WHERE family_id = ? AND id IN (?, ?)`,
		familyID, personA, personB,
	); err != nil {
		return fmt.Errorf("touch spouse persons: %w", err)
	}
	before, _ := json.Marshal(map[string]any{
		"id": edgeID, "personAId": personA, "personBId": personB,
		"status": status,
	})
	if err := insertAudit(ctx, tx, familyID, actorUserID, "relationship.deleted",
		"spouse_relationship", edgeID, "", before, nil, meta); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit spouse delete: %w", err)
	}
	return nil
}
