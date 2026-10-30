package store

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

type importPersonSnapshot struct {
	ID             string `json:"id"`
	Surname        string `json:"surname"`
	GivenName      string `json:"givenName"`
	CourtesyName   string `json:"courtesyName"`
	Alias          string `json:"alias"`
	Gender         string `json:"gender"`
	GenerationNo   int    `json:"generationNo"`
	BirthOrder     *int   `json:"birthOrder,omitempty"`
	BirthYear      *int   `json:"birthYear,omitempty"`
	BirthMonth     *int   `json:"birthMonth,omitempty"`
	BirthDay       *int   `json:"birthDay,omitempty"`
	BirthCalendar  string `json:"birthCalendar"`
	BirthLeapMonth bool   `json:"birthLeapMonth"`
	BirthDateText  string `json:"birthDateText"`
	DeathYear      *int   `json:"deathYear,omitempty"`
	DeathMonth     *int   `json:"deathMonth,omitempty"`
	DeathDay       *int   `json:"deathDay,omitempty"`
	DeathCalendar  string `json:"deathCalendar"`
	DeathLeapMonth bool   `json:"deathLeapMonth"`
	DeathDateText  string `json:"deathDateText"`
	LifeStatus     string `json:"lifeStatus"`
	BirthPlace     string `json:"birthPlace"`
	Residence      string `json:"residence"`
	Occupation     string `json:"occupation"`
	Education      string `json:"education"`
	Biography      string `json:"biography"`
}

type importPayload struct {
	RootPersonID     string                  `json:"rootPersonId"`
	SourceFamilyName string                  `json:"sourceFamilyName"`
	Persons          []importPersonSnapshot  `json:"persons"`
	ParentChild      []importParentChildEdge `json:"parentChild"`
	Spouses          []importSpouseEdge      `json:"spouses"`
}

type importParentChildEdge struct {
	ParentID   string `json:"parentId"`
	ChildID    string `json:"childId"`
	ParentRole string `json:"parentRole"`
}

type importSpouseEdge struct {
	PersonAID string `json:"personAId"`
	PersonBID string `json:"personBId"`
	Status    string `json:"status"`
}

func (s *Store) CreateImportPackage(
	ctx context.Context,
	sourceFamilyID, creatorUserID, rootPersonID string,
	meta AuditMeta,
) (*model.ImportPackage, error) {
	var role string
	if err := s.db.QueryRowContext(ctx, `
		SELECT role FROM family_memberships
		WHERE family_id = ? AND user_id = ? AND status = 'active'`,
		sourceFamilyID, creatorUserID,
	).Scan(&role); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrForbidden
		}
		return nil, fmt.Errorf("check import package owner: %w", err)
	}
	if role != "owner" {
		return nil, ErrForbidden
	}
	var rootName string
	var sourceFamilyName string
	if err := s.db.QueryRowContext(ctx, `
		SELECT p.full_name, f.name
		FROM persons p JOIN families f ON f.id = p.family_id
		WHERE p.family_id = ? AND p.id = ? AND p.status = 'active'`,
		sourceFamilyID, rootPersonID,
	).Scan(&rootName, &sourceFamilyName); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("lookup import root: %w", err)
	}

	ids, err := s.subtreePersonIDs(ctx, sourceFamilyID, rootPersonID)
	if err != nil {
		return nil, err
	}
	// Spouses of included people are part of the package so couples survive
	// the copy; descendants of those spouses are not pulled in automatically.
	spouseRows, err := s.db.QueryContext(ctx, `
		SELECT person_a_id, person_b_id, status
		FROM spouse_relationships
		WHERE family_id = ?`, sourceFamilyID)
	if err != nil {
		return nil, fmt.Errorf("list package spouses: %w", err)
	}
	included := make(map[string]bool, len(ids))
	for _, id := range ids {
		included[id] = true
	}
	spouses := make([]importSpouseEdge, 0)
	for spouseRows.Next() {
		var edge importSpouseEdge
		if err := spouseRows.Scan(&edge.PersonAID, &edge.PersonBID, &edge.Status); err != nil {
			spouseRows.Close()
			return nil, fmt.Errorf("scan package spouse: %w", err)
		}
		if included[edge.PersonAID] || included[edge.PersonBID] {
			included[edge.PersonAID] = true
			included[edge.PersonBID] = true
			spouses = append(spouses, edge)
		}
	}
	if err := spouseRows.Err(); err != nil {
		spouseRows.Close()
		return nil, fmt.Errorf("iterate package spouses: %w", err)
	}
	spouseRows.Close()

	allIDs := make([]string, 0, len(included))
	for id := range included {
		allIDs = append(allIDs, id)
	}
	persons, err := s.importPersonSnapshots(ctx, sourceFamilyID, allIDs)
	if err != nil {
		return nil, err
	}
	parentChild, err := s.importParentChildEdges(ctx, sourceFamilyID, included)
	if err != nil {
		return nil, err
	}
	filteredSpouses := make([]importSpouseEdge, 0, len(spouses))
	for _, edge := range spouses {
		if included[edge.PersonAID] && included[edge.PersonBID] {
			filteredSpouses = append(filteredSpouses, edge)
		}
	}
	payload := importPayload{
		RootPersonID: rootPersonID, SourceFamilyName: sourceFamilyName,
		Persons: persons, ParentChild: parentChild, Spouses: filteredSpouses,
	}
	raw, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("encode import package: %w", err)
	}
	expiresAt := time.Now().UTC().AddDate(0, 0, 7)
	var code string
	for attempt := 0; attempt < 8; attempt++ {
		code = randomImportCode()
		_, err = s.db.ExecContext(ctx, `
			INSERT INTO family_import_packages
				(id, source_family_id, created_by_user_id, root_person_id,
				 code, payload, person_count, relationship_count, expires_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			uuid.NewString(), sourceFamilyID, creatorUserID, rootPersonID,
			code, string(raw), len(persons), len(parentChild)+len(filteredSpouses), expiresAt,
		)
		if err == nil {
			return &model.ImportPackage{
				Code: code, SourceFamilyName: sourceFamilyName,
				RootName: rootName, PersonCount: len(persons),
				RelationshipCount: len(parentChild) + len(filteredSpouses),
				ExpiresAt:         expiresAt,
			}, nil
		}
		if !isDuplicateError(err) {
			return nil, fmt.Errorf("insert import package: %w", err)
		}
	}
	return nil, fmt.Errorf("generate unique import code")
}

func (s *Store) subtreePersonIDs(
	ctx context.Context,
	familyID, rootPersonID string,
) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, `
		WITH RECURSIVE subtree AS (
			SELECT id FROM persons
			WHERE family_id = ? AND id = ? AND status = 'active'
			UNION
			SELECT pc.child_id FROM parent_child_relationships pc
			JOIN subtree s ON pc.parent_id = s.id
			WHERE pc.family_id = ? AND pc.status = 'active'
		)
		SELECT id FROM subtree`, familyID, rootPersonID, familyID)
	if err != nil {
		return nil, fmt.Errorf("load import subtree: %w", err)
	}
	defer rows.Close()
	ids := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("scan import subtree: %w", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate import subtree: %w", err)
	}
	if len(ids) == 0 {
		return nil, ErrNotFound
	}
	return ids, nil
}

func (s *Store) importPersonSnapshots(
	ctx context.Context,
	familyID string,
	ids []string,
) ([]importPersonSnapshot, error) {
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(ids)), ",")
	args := make([]any, 0, len(ids)+1)
	args = append(args, familyID)
	for _, id := range ids {
		args = append(args, id)
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, surname, given_name, courtesy_name, alias, gender,
		       generation_no, birth_order, birth_year, birth_month, birth_day,
		       birth_calendar, birth_is_leap_month, birth_date_text,
		       death_year, death_month, death_day, death_calendar,
		       death_is_leap_month, death_date_text, life_status,
		       birth_place, residence, occupation, education, biography
		FROM persons
		WHERE family_id = ? AND id IN (`+placeholders+`)
		ORDER BY generation_no, birth_order IS NULL, birth_order, id`,
		args...)
	if err != nil {
		return nil, fmt.Errorf("load import persons: %w", err)
	}
	defer rows.Close()
	items := make([]importPersonSnapshot, 0, len(ids))
	for rows.Next() {
		var p importPersonSnapshot
		var birthOrder, birthYear, birthMonth, birthDay sql.NullInt64
		var deathYear, deathMonth, deathDay sql.NullInt64
		if err := rows.Scan(
			&p.ID, &p.Surname, &p.GivenName, &p.CourtesyName, &p.Alias,
			&p.Gender, &p.GenerationNo, &birthOrder, &birthYear,
			&birthMonth, &birthDay, &p.BirthCalendar, &p.BirthLeapMonth,
			&p.BirthDateText, &deathYear, &deathMonth, &deathDay,
			&p.DeathCalendar, &p.DeathLeapMonth, &p.DeathDateText,
			&p.LifeStatus, &p.BirthPlace, &p.Residence, &p.Occupation,
			&p.Education, &p.Biography,
		); err != nil {
			return nil, fmt.Errorf("scan import person: %w", err)
		}
		p.BirthOrder = nullIntPtr(birthOrder)
		p.BirthYear = nullIntPtr(birthYear)
		p.BirthMonth = nullIntPtr(birthMonth)
		p.BirthDay = nullIntPtr(birthDay)
		p.DeathYear = nullIntPtr(deathYear)
		p.DeathMonth = nullIntPtr(deathMonth)
		p.DeathDay = nullIntPtr(dayOrNull(deathDay))
		items = append(items, p)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate import persons: %w", err)
	}
	return items, nil
}

func nullIntPtr(value sql.NullInt64) *int {
	if !value.Valid {
		return nil
	}
	v := int(value.Int64)
	return &v
}

func dayOrNull(value sql.NullInt64) sql.NullInt64 {
	return value
}

func (s *Store) importParentChildEdges(
	ctx context.Context,
	familyID string,
	included map[string]bool,
) ([]importParentChildEdge, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT parent_id, child_id, parent_role
		FROM parent_child_relationships
		WHERE family_id = ? AND status = 'active'`, familyID)
	if err != nil {
		return nil, fmt.Errorf("load import relationships: %w", err)
	}
	defer rows.Close()
	edges := make([]importParentChildEdge, 0)
	for rows.Next() {
		var edge importParentChildEdge
		if err := rows.Scan(&edge.ParentID, &edge.ChildID, &edge.ParentRole); err != nil {
			return nil, fmt.Errorf("scan import relationship: %w", err)
		}
		if included[edge.ParentID] && included[edge.ChildID] {
			edges = append(edges, edge)
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate import relationships: %w", err)
	}
	return edges, nil
}

func (s *Store) PreviewImportPackage(
	ctx context.Context,
	code string,
) (*model.ImportPreview, error) {
	var payload []byte
	var expiresAt time.Time
	err := s.db.QueryRowContext(ctx, `
		SELECT payload, expires_at FROM family_import_packages
		WHERE code = ? AND status = 'active' AND expires_at > UTC_TIMESTAMP(6)`,
		code,
	).Scan(&payload, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("load import preview: %w", err)
	}
	var data importPayload
	if err := json.Unmarshal(payload, &data); err != nil {
		return nil, fmt.Errorf("decode import preview: %w", err)
	}
	persons := make([]model.ImportPersonPreview, 0, len(data.Persons))
	for _, person := range data.Persons {
		relation := "后裔"
		if person.ID == data.RootPersonID {
			relation = "根"
		}
		persons = append(persons, model.ImportPersonPreview{
			FullName:   person.Surname + person.GivenName,
			Generation: person.GenerationNo, Relation: relation,
		})
	}
	return &model.ImportPreview{
		Code: code, SourceFamilyName: data.SourceFamilyName,
		RootName:          findImportRootName(data),
		PersonCount:       len(data.Persons),
		RelationshipCount: len(data.ParentChild) + len(data.Spouses),
		ExpiresAt:         expiresAt, Persons: persons,
	}, nil
}

func findImportRootName(data importPayload) string {
	for _, person := range data.Persons {
		if person.ID == data.RootPersonID {
			return person.Surname + person.GivenName
		}
	}
	return ""
}

func (s *Store) ImportPackage(
	ctx context.Context,
	targetFamilyID, importerUserID, code, branchID string,
	rootGeneration int, targetParentID, parentRole string,
	meta AuditMeta,
) (*model.ImportResult, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin family import: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var role string
	if err := tx.QueryRowContext(ctx, `
		SELECT role FROM family_memberships
		WHERE family_id = ? AND user_id = ? AND status = 'active'`,
		targetFamilyID, importerUserID,
	).Scan(&role); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrForbidden
		}
		return nil, fmt.Errorf("check import target owner: %w", err)
	}
	if role != "owner" {
		return nil, ErrForbidden
	}
	var branchExists int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM branches WHERE family_id = ? AND id = ?`,
		targetFamilyID, branchID,
	).Scan(&branchExists); err != nil {
		return nil, fmt.Errorf("check import branch: %w", err)
	}
	if branchExists == 0 {
		return nil, ErrNotFound
	}
	var targetParentName string
	if targetParentID != "" {
		var parentGeneration int
		if err := tx.QueryRowContext(ctx, `
			SELECT generation_no, full_name FROM persons
			WHERE family_id = ? AND id = ? AND status = 'active'`,
			targetFamilyID, targetParentID,
		).Scan(&parentGeneration, &targetParentName); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, ErrNotFound
			}
			return nil, fmt.Errorf("lookup import parent: %w", err)
		}
		if parentGeneration >= rootGeneration {
			return nil, ErrInvalidRelationship
		}
		if parentRole != "father" && parentRole != "mother" {
			return nil, ErrInvalidRelationship
		}
	}

	var (
		packageID, sourceFamilyID string
		payload                   []byte
	)
	err = tx.QueryRowContext(ctx, `
		SELECT id, source_family_id, payload
		FROM family_import_packages
		WHERE code = ? AND status = 'active' AND expires_at > UTC_TIMESTAMP(6)
		LIMIT 1 FOR UPDATE`, code,
	).Scan(&packageID, &sourceFamilyID, &payload)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock import package: %w", err)
	}
	var data importPayload
	if err := json.Unmarshal(payload, &data); err != nil {
		return nil, fmt.Errorf("decode import package: %w", err)
	}
	var rootGenerationSource int
	for _, person := range data.Persons {
		if person.ID == data.RootPersonID {
			rootGenerationSource = person.GenerationNo
			break
		}
	}
	if rootGenerationSource == 0 {
		return nil, ErrInvalidRequest
	}
	offset := rootGeneration - rootGenerationSource
	mapping := make(map[string]string, len(data.Persons))
	for _, person := range data.Persons {
		generation := person.GenerationNo + offset
		if generation < 1 || generation > 99 {
			return nil, ErrInvalidRelationship
		}
		newID := uuid.NewString()
		mapping[person.ID] = newID
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO persons
				(id, family_id, branch_id, surname, given_name, courtesy_name, alias,
				 gender, generation_no, birth_order, birth_year, birth_month, birth_day,
				 birth_calendar, birth_is_leap_month, birth_date_text,
				 death_year, death_month, death_day, death_calendar,
				 death_is_leap_month, death_date_text, life_status,
				 birth_place, residence, occupation, education, biography, status, version)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', 1)`,
			newID, targetFamilyID, branchID, person.Surname, person.GivenName,
			person.CourtesyName, person.Alias, person.Gender, generation,
			person.BirthOrder, person.BirthYear, person.BirthMonth, person.BirthDay,
			person.BirthCalendar, person.BirthLeapMonth, person.BirthDateText,
			person.DeathYear, person.DeathMonth, person.DeathDay, person.DeathCalendar,
			person.DeathLeapMonth, person.DeathDateText, person.LifeStatus,
			person.BirthPlace, person.Residence, person.Occupation,
			person.Education, person.Biography,
		); err != nil {
			return nil, fmt.Errorf("insert imported person: %w", err)
		}
	}
	for _, edge := range data.ParentChild {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO parent_child_relationships
				(id, family_id, parent_id, child_id, parent_role, status)
			VALUES (?, ?, ?, ?, ?, 'active')`,
			uuid.NewString(), targetFamilyID, mapping[edge.ParentID],
			mapping[edge.ChildID], edge.ParentRole,
		); err != nil {
			if isDuplicateError(err) {
				return nil, ErrConflict
			}
			return nil, fmt.Errorf("insert imported relationship: %w", err)
		}
	}
	for _, edge := range data.Spouses {
		a, b := mapping[edge.PersonAID], mapping[edge.PersonBID]
		if a > b {
			a, b = b, a
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO spouse_relationships
				(id, family_id, person_a_id, person_b_id, status)
			VALUES (?, ?, ?, ?, ?)`,
			uuid.NewString(), targetFamilyID, a, b, edge.Status,
		); err != nil {
			if isDuplicateError(err) {
				return nil, ErrConflict
			}
			return nil, fmt.Errorf("insert imported spouse: %w", err)
		}
	}
	rootNewID := mapping[data.RootPersonID]
	if targetParentID != "" {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO parent_child_relationships
				(id, family_id, parent_id, child_id, parent_role, status)
			VALUES (?, ?, ?, ?, ?, 'active')`,
			uuid.NewString(), targetFamilyID, targetParentID, rootNewID, parentRole,
		); err != nil {
			if isDuplicateError(err) {
				return nil, ErrConflict
			}
			return nil, fmt.Errorf("attach imported root: %w", err)
		}
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE families SET version = version + 1 WHERE id = ?`,
		targetFamilyID,
	); err != nil {
		return nil, fmt.Errorf("touch imported family: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_import_packages
		SET status = 'used', used_by_family_id = ?, used_by_user_id = ?, used_at = UTC_TIMESTAMP(6)
		WHERE id = ? AND status = 'active'`,
		targetFamilyID, importerUserID, packageID,
	); err != nil {
		return nil, fmt.Errorf("mark import package used: %w", err)
	}
	mappingJSON, _ := json.Marshal(mapping)
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO family_imports
			(id, package_id, source_family_id, target_family_id, imported_by_user_id,
			 target_branch_id, target_parent_id, root_generation, person_count, mapping)
		VALUES (?, ?, ?, ?, ?, ?, NULLIF(?, ''), ?, ?, ?)`,
		uuid.NewString(), packageID, sourceFamilyID, targetFamilyID,
		importerUserID, branchID, targetParentID, rootGeneration,
		len(data.Persons), string(mappingJSON),
	); err != nil {
		return nil, fmt.Errorf("insert family import record: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"sourceFamilyName": data.SourceFamilyName,
		"personCount":      len(data.Persons), "rootName": findImportRootName(data),
		"rootGeneration": rootGeneration, "parent": targetParentName,
	})
	if err := insertAudit(ctx, tx, targetFamilyID, importerUserID,
		"family.imported", "family_import", packageID, "", nil, after, meta); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit family import: %w", err)
	}
	return &model.ImportResult{
		SourceFamilyName: data.SourceFamilyName,
		PersonCount:      len(data.Persons),
		RootName:         findImportRootName(data),
		RootGeneration:   rootGeneration,
	}, nil
}

func randomImportCode() string {
	const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	buf := make([]byte, 10)
	if _, err := rand.Read(buf); err != nil {
		return strings.ToUpper(uuid.NewString()[:10])
	}
	for i := range buf {
		buf[i] = alphabet[int(buf[i])%len(alphabet)]
	}
	return string(buf)
}
