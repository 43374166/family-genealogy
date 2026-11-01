package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
)

// updatePersonTx applies a complete profile update inside an existing
// transaction. It returns audit snapshots but does not write the audit row;
// both direct edits and approved edit requests need different audit actions.
func (s *Store) updatePersonTx(
	ctx context.Context,
	tx *sql.Tx,
	familyID, personID string,
	input UpdatePersonInput,
) ([]byte, []byte, error) {
	var version int
	var beforeData []byte
	err := tx.QueryRowContext(ctx, `
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
		return nil, nil, ErrNotFound
	}
	if err != nil {
		return nil, nil, fmt.Errorf("lock profile edit: %w", err)
	}
	if version != input.Version {
		return nil, nil, ErrVersionConflict
	}
	var branchExists int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM branches WHERE family_id = ? AND id = ?`,
		familyID, input.BranchID,
	).Scan(&branchExists); err != nil {
		return nil, nil, fmt.Errorf("check profile branch: %w", err)
	}
	if branchExists == 0 {
		return nil, nil, ErrNotFound
	}

	var maxParent, minChild, badSpouses int
	if err := tx.QueryRowContext(ctx, `
		SELECT COALESCE(MAX(p.generation_no), 0)
		FROM parent_child_relationships pc
		JOIN persons p ON p.id = pc.parent_id AND p.family_id = pc.family_id
		WHERE pc.family_id = ? AND pc.child_id = ? AND pc.status = 'active'`,
		familyID, personID,
	).Scan(&maxParent); err != nil {
		return nil, nil, fmt.Errorf("check profile parents: %w", err)
	}
	if err := tx.QueryRowContext(ctx, `
		SELECT COALESCE(MIN(p.generation_no), 0)
		FROM parent_child_relationships pc
		JOIN persons p ON p.id = pc.child_id AND p.family_id = pc.family_id
		WHERE pc.family_id = ? AND pc.parent_id = ? AND pc.status = 'active'`,
		familyID, personID,
	).Scan(&minChild); err != nil {
		return nil, nil, fmt.Errorf("check profile children: %w", err)
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
		return nil, nil, fmt.Errorf("check profile spouses: %w", err)
	}
	if maxParent >= input.GenerationNo || (minChild > 0 && minChild <= input.GenerationNo) || badSpouses > 0 {
		return nil, nil, ErrInvalidRelationship
	}

	if input.BirthYear != nil && input.BirthMonth == nil && input.BirthDay == nil && input.BirthCalendar == "" {
		_, month, day, calendar, leap, loadErr := loadExistingDate(tx, personID, "birth")
		if loadErr == nil {
			input.BirthMonth, input.BirthDay = month, day
			input.BirthCalendar, input.BirthIsLeapMonth = calendar, leap
		}
	}
	if input.LifeStatus != "deceased" {
		input.DeathYear = nil
		input.DeathMonth, input.DeathDay = nil, nil
		input.DeathCalendar, input.DeathIsLeapMonth = "", false
	} else if input.DeathYear != nil && input.DeathMonth == nil && input.DeathDay == nil && input.DeathCalendar == "" {
		_, month, day, calendar, leap, loadErr := loadExistingDate(tx, personID, "death")
		if loadErr == nil {
			input.DeathMonth, input.DeathDay = month, day
			input.DeathCalendar, input.DeathIsLeapMonth = calendar, leap
		}
	}
	birthDate, err := normalizeEventDate(
		input.BirthYear, input.BirthMonth, input.BirthDay,
		input.BirthCalendar, input.BirthIsLeapMonth,
	)
	if err != nil {
		return nil, nil, fmt.Errorf("%w: birth date: %v", ErrInvalidDate, err)
	}
	deathDate := normalizedDate{calendar: "unknown"}
	if input.LifeStatus == "deceased" {
		deathDate, err = normalizeEventDate(
			input.DeathYear, input.DeathMonth, input.DeathDay,
			input.DeathCalendar, input.DeathIsLeapMonth,
		)
		if err != nil {
			return nil, nil, fmt.Errorf("%w: death date: %v", ErrInvalidDate, err)
		}
	}
	if input.LifeStatus != "living" && input.LifeStatus != "deceased" && input.LifeStatus != "unknown" {
		return nil, nil, fmt.Errorf("%w: invalid life status", ErrInvalidDate)
	}
	var birthOrder any
	if input.BirthOrder != nil {
		birthOrder = *input.BirthOrder
	}
	birthYear, birthMonth, birthDay := birthDate.nullable()
	deathYear, deathMonth, deathDay := deathDate.nullable()
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons
		SET surname = ?, given_name = ?, courtesy_name = ?, alias = ?,
		    gender = ?, generation_no = ?, branch_id = ?, birth_order = ?,
		    birth_year = ?, birth_month = ?, birth_day = ?,
		    birth_calendar = ?, birth_is_leap_month = ?, birth_date_text = ?,
		    death_year = ?, death_month = ?, death_day = ?,
		    death_calendar = ?, death_is_leap_month = ?, death_date_text = ?,
		    life_status = ?, birth_place = ?, residence = ?, occupation = ?,
		    education = ?, biography = ?, version = version + 1
		WHERE id = ? AND family_id = ? AND version = ?`,
		input.Surname, input.GivenName, input.CourtesyName, input.Alias,
		input.Gender, input.GenerationNo, input.BranchID, birthOrder,
		birthYear, birthMonth, birthDay,
		birthDate.calendar, birthDate.leap, birthDate.text,
		deathYear, deathMonth, deathDay,
		deathDate.calendar, deathDate.leap, deathDate.text,
		input.LifeStatus, input.BirthPlace, input.Residence, input.Occupation,
		input.Education, input.Biography, personID, familyID, input.Version,
	); err != nil {
		return nil, nil, fmt.Errorf("update profile: %w", err)
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
	return beforeData, afterData, nil
}
