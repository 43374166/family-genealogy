package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

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
	p.gender, p.generation_no, p.generation_name, p.birth_order, p.branch_id,
	p.birth_year, p.birth_month, p.birth_day, p.birth_calendar, p.birth_is_leap_month, p.birth_date_text,
	p.death_year, p.death_month, p.death_day, p.death_calendar, p.death_is_leap_month, p.death_date_text,
	p.life_status, p.status, p.version, (p.avatar_object_key IS NOT NULL)`

type rowScanner interface {
	Scan(dest ...any) error
}

func scanPersonSummary(scanner rowScanner) (*model.PersonSummary, error) {
	var person model.PersonSummary
	var branchID sql.NullString
	var birthOrder sql.NullInt64
	var birthYear, birthMonth, birthDay sql.NullInt64
	var deathYear, deathMonth, deathDay sql.NullInt64
	var birthCalendar, birthText, deathCalendar, deathText string
	var birthLeap, deathLeap bool

	err := scanner.Scan(
		&person.ID, &person.FullName, &person.Surname, &person.GivenName,
		&person.CourtesyName, &person.Alias, &person.Gender,
		&person.GenerationNo, &person.GenerationName, &birthOrder, &branchID,
		&birthYear, &birthMonth, &birthDay, &birthCalendar, &birthLeap, &birthText,
		&deathYear, &deathMonth, &deathDay, &deathCalendar, &deathLeap, &deathText,
		&person.LifeStatus, &person.Status, &person.Version, &person.HasAvatar,
	)
	if err != nil {
		return nil, err
	}
	if branchID.Valid {
		v := branchID.String
		person.BranchID = &v
	}
	if birthOrder.Valid {
		v := int(birthOrder.Int64)
		person.BirthOrder = &v
	}
	person.GenerationLabel = generationLabel(person.GenerationNo, person.GenerationName)
	person.Birth = buildPartialDate(birthYear, birthMonth, birthDay, birthCalendar, birthLeap, birthText)
	person.Death = buildPartialDate(deathYear, deathMonth, deathDay, deathCalendar, deathLeap, deathText)
	return &person, nil
}

func generationLabel(generationNo int, name string) string {
	label := model.GenerationLabel(generationNo)
	if name == "" {
		return label
	}
	return label + "(" + name + ")"
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
	var birthOrder sql.NullInt64
	var birthYear, birthMonth, birthDay sql.NullInt64
	var deathYear, deathMonth, deathDay sql.NullInt64
	var birthCalendar, birthText, deathCalendar, deathText string
	var birthLeap, deathLeap bool
	err := row.Scan(
		&person.ID, &person.FullName, &person.Surname, &person.GivenName,
		&person.CourtesyName, &person.Alias, &person.Gender,
		&person.GenerationNo, &person.GenerationName, &birthOrder, &branchID,
		&birthYear, &birthMonth, &birthDay, &birthCalendar, &birthLeap, &birthText,
		&deathYear, &deathMonth, &deathDay, &deathCalendar, &deathLeap, &deathText,
		&person.LifeStatus, &person.Status, &person.Version, &person.HasAvatar,
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
	if birthOrder.Valid {
		v := int(birthOrder.Int64)
		person.BirthOrder = &v
	}
	person.GenerationLabel = generationLabel(person.GenerationNo, person.GenerationName)
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
	if person.Siblings, err = s.siblings(ctx, familyID, personID, person.Birth, person.CreatedAt); err != nil {
		return nil, err
	}
	return &person, nil
}

func (s *Store) siblings(
	ctx context.Context, familyID, personID string,
	selfBirth *model.PartialDate, selfCreated time.Time,
) ([]model.Relative, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT DISTINCT p.id, p.full_name, p.gender,
		       p.birth_year, p.birth_month, p.birth_day, p.created_at
		FROM parent_child_relationships mine
		JOIN parent_child_relationships sibling
		  ON sibling.family_id = mine.family_id
		 AND sibling.parent_id = mine.parent_id
		 AND sibling.status = 'active'
		JOIN persons p ON p.id = sibling.child_id
		 AND p.family_id = mine.family_id AND p.status = 'active'
		WHERE mine.family_id = ? AND mine.child_id = ?
		  AND mine.status = 'active' AND p.id <> ?
		ORDER BY p.birth_year IS NULL, p.birth_year, p.created_at, p.id`,
		familyID, personID, personID)
	if err != nil {
		return nil, fmt.Errorf("list siblings: %w", err)
	}
	defer rows.Close()

	type siblingRow struct {
		relative  model.Relative
		gender    string
		birth     *model.PartialDate
		createdAt time.Time
	}
	rowsList := make([]siblingRow, 0)
	for rows.Next() {
		var item siblingRow
		var by, bm, bd sql.NullInt64
		if err := rows.Scan(&item.relative.PersonID, &item.relative.FullName,
			&item.gender, &by, &bm, &bd, &item.createdAt); err != nil {
			return nil, fmt.Errorf("scan sibling: %w", err)
		}
		if by.Valid || bm.Valid || bd.Valid {
			item.birth = buildPartialDate(by, bm, bd, "gregorian", false, "")
		}
		rowsList = append(rowsList, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate siblings: %w", err)
	}
	sort.SliceStable(rowsList, func(i, j int) bool {
		a, b := rowsList[i], rowsList[j]
		if (a.birth != nil) != (b.birth != nil) {
			return a.birth != nil
		}
		if a.birth != nil && b.birth != nil {
			ak := fmt.Sprintf("%04d%02d%02d", derefInt(a.birth.Year),
				derefInt(a.birth.Month), derefInt(a.birth.Day))
			bk := fmt.Sprintf("%04d%02d%02d", derefInt(b.birth.Year),
				derefInt(b.birth.Month), derefInt(b.birth.Day))
			if ak != bk {
				return ak < bk
			}
		}
		return a.createdAt.Before(b.createdAt)
	})
	result := make([]model.Relative, 0, len(rowsList))
	for _, item := range rowsList {
		older := siblingIsOlder(selfBirth, selfCreated, item.birth, item.createdAt)
		prefix := "兄弟"
		if item.gender == "female" {
			prefix = "姐"
			if !older {
				prefix = "妹"
			}
		} else {
			prefix = "哥"
			if !older {
				prefix = "弟"
			}
		}
		item.relative.Relation = prefix
		result = append(result, item.relative)
	}
	return result, nil
}

func derefInt(value *int) int {
	if value == nil {
		return 0
	}
	return *value
}

func siblingIsOlder(
	selfBirth *model.PartialDate, selfCreated time.Time,
	otherBirth *model.PartialDate, otherCreated time.Time,
) bool {
	if selfBirth != nil && otherBirth != nil &&
		selfBirth.Year != nil && selfBirth.Month != nil && selfBirth.Day != nil &&
		otherBirth.Year != nil && otherBirth.Month != nil && otherBirth.Day != nil {
		sk := fmt.Sprintf("%04d%02d%02d", *selfBirth.Year, *selfBirth.Month, *selfBirth.Day)
		ok := fmt.Sprintf("%04d%02d%02d", *otherBirth.Year, *otherBirth.Month, *otherBirth.Day)
		if sk != ok {
			return ok < sk
		}
	}
	return otherCreated.Before(selfCreated)
}

func (s *Store) relations(ctx context.Context, familyID, personID, kind string) ([]model.Relative, error) {
	var query string
	switch kind {
	case "parents":
		query = `
			SELECT pc.id, p.id, p.full_name, pc.parent_role
			FROM parent_child_relationships pc
			JOIN persons p ON p.id = pc.parent_id AND p.family_id = pc.family_id
			WHERE pc.child_id = ? AND pc.family_id = ? AND pc.status = 'active'
			ORDER BY p.birth_year IS NULL, p.birth_year ASC, p.id ASC`
	case "children":
		query = `
			SELECT pc.id, p.id, p.full_name, 'child'
			FROM parent_child_relationships pc
			JOIN persons p ON p.id = pc.child_id AND p.family_id = pc.family_id
			WHERE pc.parent_id = ? AND pc.family_id = ? AND pc.status = 'active'
			ORDER BY p.birth_year IS NULL, p.birth_year ASC, p.id ASC`
	case "spouses":
		query = `
			SELECT s.id, p.id, p.full_name, s.status
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
		if err := rows.Scan(&relative.EdgeID, &relative.PersonID, &relative.FullName, &relation); err != nil {
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
