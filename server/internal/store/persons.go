package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
)

type PersonFilter struct {
	Query      string
	Generation int
	BranchID   string
	Cursor     string
	Limit      int
}

const personSummaryColumns = `
	p.id, p.full_name, p.surname, p.given_name, p.courtesy_name, p.alias,
	p.gender, p.generation_no, p.branch_id,
	p.birth_year, p.birth_month, p.birth_day, p.birth_calendar, p.birth_is_leap_month, p.birth_date_text,
	p.death_year, p.death_month, p.death_day, p.death_calendar, p.death_is_leap_month, p.death_date_text,
	p.life_status, p.status, p.version`

type rowScanner interface {
	Scan(dest ...any) error
}

func scanPersonSummary(scanner rowScanner) (*model.PersonSummary, error) {
	var person model.PersonSummary
	var branchID sql.NullString
	var birthYear, birthMonth, birthDay sql.NullInt64
	var deathYear, deathMonth, deathDay sql.NullInt64
	var birthCalendar, birthText, deathCalendar, deathText string
	var birthLeap, deathLeap bool

	err := scanner.Scan(
		&person.ID, &person.FullName, &person.Surname, &person.GivenName,
		&person.CourtesyName, &person.Alias, &person.Gender,
		&person.GenerationNo, &branchID,
		&birthYear, &birthMonth, &birthDay, &birthCalendar, &birthLeap, &birthText,
		&deathYear, &deathMonth, &deathDay, &deathCalendar, &deathLeap, &deathText,
		&person.LifeStatus, &person.Status, &person.Version,
	)
	if err != nil {
		return nil, err
	}
	if branchID.Valid {
		v := branchID.String
		person.BranchID = &v
	}
	person.GenerationLabel = model.GenerationLabel(person.GenerationNo)
	person.Birth = buildPartialDate(birthYear, birthMonth, birthDay, birthCalendar, birthLeap, birthText)
	person.Death = buildPartialDate(deathYear, deathMonth, deathDay, deathCalendar, deathLeap, deathText)
	return &person, nil
}

func buildPartialDate(year, month, day sql.NullInt64, calendar string, leap bool, text string) *model.PartialDate {
	if !year.Valid && !month.Valid && !day.Valid && calendar == "" && text == "" {
		return nil
	}
	date := &model.PartialDate{Calendar: calendar, IsLeapMonth: leap, Text: text}
	if year.Valid {
		v := int(year.Int64)
		date.Year = &v
	}
	if month.Valid {
		v := int(month.Int64)
		date.Month = &v
	}
	if day.Valid {
		v := int(day.Int64)
		date.Day = &v
	}
	return date
}

func (s *Store) ListPersons(ctx context.Context, familyID string, filter PersonFilter) ([]model.PersonSummary, string, error) {
	if filter.Limit < 1 || filter.Limit > 100 {
		filter.Limit = 20
	}

	query := `SELECT ` + personSummaryColumns + ` FROM persons p WHERE p.family_id = ? AND p.status = 'active'`
	args := []any{familyID}
	if q := strings.TrimSpace(filter.Query); q != "" {
		pattern := "%" + q + "%"
		query += ` AND (p.full_name LIKE ? OR p.alias LIKE ? OR p.courtesy_name LIKE ?)`
		args = append(args, pattern, pattern, pattern)
	}
	if filter.Generation > 0 {
		query += ` AND p.generation_no = ?`
		args = append(args, filter.Generation)
	}
	if filter.BranchID != "" {
		query += ` AND p.branch_id = ?`
		args = append(args, filter.BranchID)
	}
	if filter.Cursor != "" {
		query += ` AND p.id > ?`
		args = append(args, filter.Cursor)
	}
	query += ` ORDER BY p.id ASC LIMIT ?`
	args = append(args, filter.Limit+1)

	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, "", fmt.Errorf("list persons: %w", err)
	}
	defer rows.Close()

	persons := make([]model.PersonSummary, 0, filter.Limit)
	for rows.Next() {
		person, err := scanPersonSummary(rows)
		if err != nil {
			return nil, "", fmt.Errorf("scan person: %w", err)
		}
		persons = append(persons, *person)
	}
	if err := rows.Err(); err != nil {
		return nil, "", fmt.Errorf("iterate persons: %w", err)
	}

	nextCursor := ""
	if len(persons) > filter.Limit {
		nextCursor = persons[filter.Limit-1].ID
		persons = persons[:filter.Limit]
	}
	return persons, nextCursor, nil
}

func (s *Store) GetPerson(ctx context.Context, familyID, personID string) (*model.Person, error) {
	query := `SELECT ` + personSummaryColumns + `,
		p.birth_place, p.residence, p.occupation, p.education, p.biography, p.created_at, p.updated_at
		FROM persons p WHERE p.family_id = ? AND p.id = ? AND p.status = 'active' LIMIT 1`
	row := s.db.QueryRowContext(ctx, query, familyID, personID)

	var person model.Person
	var branchID sql.NullString
	var birthYear, birthMonth, birthDay sql.NullInt64
	var deathYear, deathMonth, deathDay sql.NullInt64
	var birthCalendar, birthText, deathCalendar, deathText string
	var birthLeap, deathLeap bool
	err := row.Scan(
		&person.ID, &person.FullName, &person.Surname, &person.GivenName,
		&person.CourtesyName, &person.Alias, &person.Gender,
		&person.GenerationNo, &branchID,
		&birthYear, &birthMonth, &birthDay, &birthCalendar, &birthLeap, &birthText,
		&deathYear, &deathMonth, &deathDay, &deathCalendar, &deathLeap, &deathText,
		&person.LifeStatus, &person.Status, &person.Version,
		&person.BirthPlace, &person.Residence, &person.Occupation, &person.Education,
		&person.Biography, &person.CreatedAt, &person.UpdatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get person: %w", err)
	}
	if branchID.Valid {
		v := branchID.String
		person.BranchID = &v
	}
	person.GenerationLabel = model.GenerationLabel(person.GenerationNo)
	person.Birth = buildPartialDate(birthYear, birthMonth, birthDay, birthCalendar, birthLeap, birthText)
	person.Death = buildPartialDate(deathYear, deathMonth, deathDay, deathCalendar, deathLeap, deathText)

	if person.Parents, err = s.relations(ctx, familyID, personID, "parents"); err != nil {
		return nil, err
	}
	if person.Children, err = s.relations(ctx, familyID, personID, "children"); err != nil {
		return nil, err
	}
	if person.Spouses, err = s.relations(ctx, familyID, personID, "spouses"); err != nil {
		return nil, err
	}
	return &person, nil
}

func (s *Store) relations(ctx context.Context, familyID, personID, kind string) ([]model.Relative, error) {
	var query string
	switch kind {
	case "parents":
		query = `
			SELECT p.id, p.full_name, pc.parent_role
			FROM parent_child_relationships pc
			JOIN persons p ON p.id = pc.parent_id AND p.family_id = pc.family_id
			WHERE pc.child_id = ? AND pc.family_id = ? AND pc.status = 'active'
			ORDER BY p.birth_year IS NULL, p.birth_year ASC, p.id ASC`
	case "children":
		query = `
			SELECT p.id, p.full_name, 'child'
			FROM parent_child_relationships pc
			JOIN persons p ON p.id = pc.child_id AND p.family_id = pc.family_id
			WHERE pc.parent_id = ? AND pc.family_id = ? AND pc.status = 'active'
			ORDER BY p.birth_year IS NULL, p.birth_year ASC, p.id ASC`
	case "spouses":
		query = `
			SELECT p.id, p.full_name, s.status
			FROM spouse_relationships s
			JOIN persons p ON p.family_id = s.family_id
			 AND p.id = CASE WHEN s.person_a_id = ? THEN s.person_b_id ELSE s.person_a_id END
			WHERE s.family_id = ? AND (s.person_a_id = ? OR s.person_b_id = ?)
			ORDER BY p.birth_year IS NULL, p.birth_year ASC, p.id ASC`
	default:
		return nil, fmt.Errorf("unknown relation kind %q", kind)
	}

	args := []any{personID, familyID}
	if kind == "spouses" {
		args = append(args, personID, personID)
	}
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list %s: %w", kind, err)
	}
	defer rows.Close()

	result := make([]model.Relative, 0)
	for rows.Next() {
		var relative model.Relative
		var relation string
		if err := rows.Scan(&relative.PersonID, &relative.FullName, &relation); err != nil {
			return nil, fmt.Errorf("scan %s: %w", kind, err)
		}
		switch kind {
		case "parents":
			relative.Relation = model.RoleLabel(relation)
		case "children":
			relative.Relation = "子女"
		case "spouses":
			relative.Relation = "配偶"
		}
		result = append(result, relative)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate %s: %w", kind, err)
	}
	return result, nil
}
