package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

var (
	ErrInvalidRelationship = errors.New("invalid relationship")
	ErrCycle               = errors.New("relationship cycle")
	ErrInvalidDate         = errors.New("invalid date")
)

type NewPerson struct {
	Surname          string `json:"surname"`
	GivenName        string `json:"givenName"`
	CourtesyName     string `json:"courtesyName,omitempty"`
	Alias            string `json:"alias,omitempty"`
	Gender           string `json:"gender"`
	GenerationNo     int    `json:"generationNo"`
	BranchID         string `json:"branchId"`
	BirthOrder       *int   `json:"birthOrder,omitempty"`
	BirthYear        *int   `json:"birthYear,omitempty"`
	BirthMonth       *int   `json:"birthMonth,omitempty"`
	BirthDay         *int   `json:"birthDay,omitempty"`
	BirthCalendar    string `json:"birthCalendar,omitempty"`
	BirthIsLeapMonth bool   `json:"birthIsLeapMonth,omitempty"`
	DeathYear        *int   `json:"deathYear,omitempty"`
	DeathMonth       *int   `json:"deathMonth,omitempty"`
	DeathDay         *int   `json:"deathDay,omitempty"`
	DeathCalendar    string `json:"deathCalendar,omitempty"`
	DeathIsLeapMonth bool   `json:"deathIsLeapMonth,omitempty"`
	LifeStatus       string `json:"lifeStatus,omitempty"`
	Biography        string `json:"biography,omitempty"`
}

type ParentChildInput struct {
	ParentID   string `json:"parentId"`
	ChildID    string `json:"childId"`
	ParentRole string `json:"parentRole"`
}

type SpouseInput struct {
	PersonAID string `json:"personAId"`
	PersonBID string `json:"personBId"`
}

func (s *Store) CreatePerson(
	ctx context.Context,
	familyID, actorUserID string,
	input NewPerson,
	meta AuditMeta,
) (*model.Person, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin create person: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var branchExists int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM branches WHERE family_id = ? AND id = ?`,
		familyID, input.BranchID,
	).Scan(&branchExists); err != nil {
		return nil, fmt.Errorf("check branch: %w", err)
	}
	if branchExists == 0 {
		return nil, ErrNotFound
	}

	birthDate, err := normalizeEventDate(
		input.BirthYear, input.BirthMonth, input.BirthDay,
		input.BirthCalendar, input.BirthIsLeapMonth,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: birth date: %v", ErrInvalidDate, err)
	}
	lifeStatus := input.LifeStatus
	if lifeStatus == "" {
		lifeStatus = "living"
	}
	if lifeStatus != "living" && lifeStatus != "deceased" && lifeStatus != "unknown" {
		return nil, fmt.Errorf("%w: invalid life status", ErrInvalidDate)
	}
	deathDate := normalizedDate{calendar: "unknown"}
	if lifeStatus == "deceased" {
		deathDate, err = normalizeEventDate(
			input.DeathYear, input.DeathMonth, input.DeathDay,
			input.DeathCalendar, input.DeathIsLeapMonth,
		)
		if err != nil {
			return nil, fmt.Errorf("%w: death date: %v", ErrInvalidDate, err)
		}
	}
	birthYear, birthMonth, birthDay := birthDate.nullable()
	deathYear, deathMonth, deathDay := deathDate.nullable()
	personID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO persons
			(id, family_id, branch_id, surname, given_name, courtesy_name, alias,
			 gender, generation_no, birth_order, birth_year, birth_month, birth_day,
			 birth_calendar, birth_is_leap_month, birth_date_text,
			 death_year, death_month, death_day, death_calendar, death_is_leap_month,
			 death_date_text, life_status, biography)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		personID, familyID, input.BranchID, input.Surname, input.GivenName,
		input.CourtesyName, input.Alias, input.Gender, input.GenerationNo,
		input.BirthOrder, birthYear, birthMonth, birthDay,
		birthDate.calendar, birthDate.leap, birthDate.text,
		deathYear, deathMonth, deathDay, deathDate.calendar, deathDate.leap,
		deathDate.text, lifeStatus, input.Biography,
	); err != nil {
		return nil, fmt.Errorf("insert person: %w", err)
	}

	after, err := json.Marshal(map[string]any{
		"id":            personID,
		"branchId":      input.BranchID,
		"fullName":      input.Surname + input.GivenName,
		"gender":        input.Gender,
		"generationNo":  input.GenerationNo,
		"birthOrder":    input.BirthOrder,
		"birthYear":     input.BirthYear,
		"birthMonth":    input.BirthMonth,
		"birthDay":      input.BirthDay,
		"birthCalendar": birthDate.calendar,
		"lifeStatus":    lifeStatus,
	})
	if err != nil {
		return nil, fmt.Errorf("encode person audit: %w", err)
	}
	if err := insertAudit(ctx, tx, familyID, actorUserID, "person.created",
		"person", personID, "", nil, after, meta); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit create person: %w", err)
	}
	return s.GetPerson(ctx, familyID, personID)
}

func (s *Store) AddParentChild(
	ctx context.Context,
	familyID, actorUserID string,
	input ParentChildInput,
	meta AuditMeta,
) (*model.ParentChildEdge, error) {
	if input.ParentID == input.ChildID {
		return nil, ErrInvalidRelationship
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin parent-child: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	people, err := lockPeople(ctx, tx, familyID, input.ParentID, input.ChildID)
	if err != nil {
		return nil, err
	}
	parent := people[input.ParentID]
	child := people[input.ChildID]
	if parent == nil || child == nil {
		return nil, ErrNotFound
	}
	if parent.GenerationNo >= child.GenerationNo {
		return nil, ErrInvalidRelationship
	}

	var duplicate int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM parent_child_relationships
		WHERE family_id = ? AND parent_id = ? AND child_id = ? AND status = 'active'`,
		familyID, input.ParentID, input.ChildID,
	).Scan(&duplicate); err != nil {
		return nil, fmt.Errorf("check parent-child duplicate: %w", err)
	}
	if duplicate > 0 {
		return nil, ErrConflict
	}
	var roleTaken int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM parent_child_relationships
		WHERE family_id = ? AND child_id = ? AND parent_role = ? AND status = 'active'`,
		familyID, input.ChildID, input.ParentRole,
	).Scan(&roleTaken); err != nil {
		return nil, fmt.Errorf("check parent role: %w", err)
	}
	if roleTaken > 0 {
		return nil, ErrConflict
	}

	edgeID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO parent_child_relationships
			(id, family_id, parent_id, child_id, parent_role, status)
		VALUES (?, ?, ?, ?, ?, 'active')`,
		edgeID, familyID, input.ParentID, input.ChildID, input.ParentRole,
	); err != nil {
		if isDuplicateError(err) {
			return nil, ErrConflict
		}
		if isCycleError(err) {
			return nil, ErrCycle
		}
		return nil, fmt.Errorf("insert parent-child: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons SET version = version + 1
		WHERE family_id = ? AND id IN (?, ?)`,
		familyID, input.ParentID, input.ChildID,
	); err != nil {
		return nil, fmt.Errorf("touch parent-child persons: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"parentId":   input.ParentID,
		"childId":    input.ChildID,
		"parentRole": input.ParentRole,
	})
	if err := insertAudit(ctx, tx, familyID, actorUserID,
		"relationship.parent_child.created", "parent_child_relationship",
		edgeID, "", nil, after, meta); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit parent-child: %w", err)
	}
	return &model.ParentChildEdge{
		ID: edgeID, ParentID: input.ParentID, ChildID: input.ChildID,
		ParentRole: input.ParentRole, Status: "active",
	}, nil
}

func (s *Store) AddSpouse(
	ctx context.Context,
	familyID, actorUserID string,
	input SpouseInput,
	meta AuditMeta,
) (*model.SpouseEdge, error) {
	if input.PersonAID == input.PersonBID {
		return nil, ErrInvalidRelationship
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin spouse: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	people, err := lockPeople(ctx, tx, familyID, input.PersonAID, input.PersonBID)
	if err != nil {
		return nil, err
	}
	a := people[input.PersonAID]
	b := people[input.PersonBID]
	if a == nil || b == nil {
		return nil, ErrNotFound
	}
	if a.GenerationNo != b.GenerationNo {
		return nil, ErrInvalidRelationship
	}
	ids := []string{input.PersonAID, input.PersonBID}
	sort.Strings(ids)

	var duplicate int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM spouse_relationships
		WHERE family_id = ? AND person_a_id = ? AND person_b_id = ?`,
		familyID, ids[0], ids[1],
	).Scan(&duplicate); err != nil {
		return nil, fmt.Errorf("check spouse duplicate: %w", err)
	}
	if duplicate > 0 {
		return nil, ErrConflict
	}

	edgeID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO spouse_relationships
			(id, family_id, person_a_id, person_b_id, status)
		VALUES (?, ?, ?, ?, 'married')`,
		edgeID, familyID, ids[0], ids[1],
	); err != nil {
		if isDuplicateError(err) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("insert spouse: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE persons SET version = version + 1
		WHERE family_id = ? AND id IN (?, ?)`,
		familyID, ids[0], ids[1],
	); err != nil {
		return nil, fmt.Errorf("touch spouse persons: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"personAId": ids[0],
		"personBId": ids[1],
		"status":    "married",
	})
	if err := insertAudit(ctx, tx, familyID, actorUserID,
		"relationship.spouse.created", "spouse_relationship",
		edgeID, "", nil, after, meta); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit spouse: %w", err)
	}
	return &model.SpouseEdge{
		ID: edgeID, PersonAID: ids[0], PersonBID: ids[1], Status: "married",
	}, nil
}

type lockedPerson struct {
	GenerationNo int
}

func lockPeople(ctx context.Context, tx *sql.Tx, familyID string, ids ...string) (map[string]*lockedPerson, error) {
	query := `SELECT id, generation_no FROM persons
		WHERE family_id = ? AND status = 'active' AND id IN (`
	args := []any{familyID}
	for index, id := range ids {
		if index > 0 {
			query += ","
		}
		query += "?"
		args = append(args, id)
	}
	query += ") FOR UPDATE"
	rows, err := tx.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("lock people: %w", err)
	}
	defer rows.Close()

	result := make(map[string]*lockedPerson, len(ids))
	for rows.Next() {
		var id string
		var person lockedPerson
		if err := rows.Scan(&id, &person.GenerationNo); err != nil {
			return nil, fmt.Errorf("scan locked person: %w", err)
		}
		value := person
		result[id] = &value
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate locked people: %w", err)
	}
	return result, nil
}

func isDuplicateError(err error) bool {
	return strings.Contains(strings.ToLower(err.Error()), "duplicate entry")
}

func isCycleError(err error) bool {
	return strings.Contains(strings.ToLower(err.Error()), "cycle")
}
