package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

var (
	ErrConflict        = errors.New("conflict")
	ErrVersionConflict = errors.New("version conflict")
	ErrNoChanges       = errors.New("no changes")
	ErrForbidden       = errors.New("forbidden")
	ErrInvalidRequest  = errors.New("invalid request type")
)

type EditRequestFilter struct {
	Status          string
	RequesterUserID string
	Limit           int
}

type AuditMeta struct {
	IP        string
	UserAgent string
	TraceID   string
}

type editablePerson struct {
	FullName   string
	BirthPlace string
	Residence  string
	Occupation string
	Education  string
	Biography  string
	Version    int
	Status     string
}

func (s *Store) CreateEditRequest(
	ctx context.Context,
	familyID, requesterUserID, targetPersonID string,
	baseVersion int,
	changes model.PersonEditChanges,
) (*model.EditRequest, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin edit request: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var current editablePerson
	err = tx.QueryRowContext(ctx, `
		SELECT full_name, birth_place, residence, occupation, education, biography, version, status
		FROM persons
		WHERE family_id = ? AND id = ?
		LIMIT 1
		FOR UPDATE`, familyID, targetPersonID,
	).Scan(
		&current.FullName, &current.BirthPlace, &current.Residence,
		&current.Occupation, &current.Education, &current.Biography,
		&current.Version, &current.Status,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock edit target: %w", err)
	}
	if current.Status != "active" {
		return nil, ErrNotFound
	}
	if baseVersion != current.Version {
		return nil, ErrVersionConflict
	}

	normalized := normalizeChanges(changes, current)
	if normalized.Empty() {
		return nil, ErrNoChanges
	}
	payload, err := json.Marshal(normalized)
	if err != nil {
		return nil, fmt.Errorf("encode edit changes: %w", err)
	}
	requestID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO edit_requests
			(id, family_id, requester_user_id, request_type, target_person_id,
			 base_version, payload, status)
		VALUES (?, ?, ?, 'update_person', ?, ?, ?, 'pending')`,
		requestID, familyID, requesterUserID, targetPersonID,
		current.Version, string(payload),
	); err != nil {
		return nil, fmt.Errorf("insert edit request: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit edit request: %w", err)
	}
	return s.GetEditRequest(ctx, familyID, requestID)
}

func normalizeChanges(changes model.PersonEditChanges, current editablePerson) model.PersonEditChanges {
	if changes.BirthPlace != nil && *changes.BirthPlace == current.BirthPlace {
		changes.BirthPlace = nil
	}
	if changes.Residence != nil && *changes.Residence == current.Residence {
		changes.Residence = nil
	}
	if changes.Occupation != nil && *changes.Occupation == current.Occupation {
		changes.Occupation = nil
	}
	if changes.Education != nil && *changes.Education == current.Education {
		changes.Education = nil
	}
	if changes.Biography != nil && *changes.Biography == current.Biography {
		changes.Biography = nil
	}
	return changes
}

func (s *Store) CreateWriteRequest(
	ctx context.Context,
	familyID, requesterUserID, requestType string,
	payload []byte,
) (*model.EditRequest, error) {
	requestID := uuid.NewString()
	if _, err := s.db.ExecContext(ctx, `
		INSERT INTO edit_requests
			(id, family_id, requester_user_id, request_type, payload, status)
		VALUES (?, ?, ?, ?, ?, 'pending')`,
		requestID, familyID, requesterUserID, requestType, string(payload),
	); err != nil {
		return nil, fmt.Errorf("insert write request: %w", err)
	}
	return s.GetEditRequest(ctx, familyID, requestID)
}

func (s *Store) GetEditRequest(ctx context.Context, familyID, requestID string) (*model.EditRequest, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT r.id, r.family_id, r.requester_user_id, u.display_name,
		       r.request_type, r.target_person_id, COALESCE(p.full_name, ''),
		       r.base_version, r.payload, r.status,
		       r.reviewer_user_id, COALESCE(rv.display_name, ''), r.review_note,
		       r.submitted_at, r.reviewed_at
		FROM edit_requests r
		JOIN users u ON u.id = r.requester_user_id
		LEFT JOIN persons p
		  ON p.id = r.target_person_id AND p.family_id = r.family_id
		LEFT JOIN users rv ON rv.id = r.reviewer_user_id
		WHERE r.family_id = ? AND r.id = ?
		LIMIT 1`, familyID, requestID)
	return scanEditRequest(row)
}

func (s *Store) ListEditRequests(
	ctx context.Context,
	familyID string,
	filter EditRequestFilter,
) ([]model.EditRequest, error) {
	if filter.Limit < 1 || filter.Limit > 100 {
		filter.Limit = 50
	}
	query := `
		SELECT r.id, r.family_id, r.requester_user_id, u.display_name,
		       r.request_type, r.target_person_id, COALESCE(p.full_name, ''),
		       r.base_version, r.payload, r.status,
		       r.reviewer_user_id, COALESCE(rv.display_name, ''), r.review_note,
		       r.submitted_at, r.reviewed_at
		FROM edit_requests r
		JOIN users u ON u.id = r.requester_user_id
		LEFT JOIN persons p
		  ON p.id = r.target_person_id AND p.family_id = r.family_id
		LEFT JOIN users rv ON rv.id = r.reviewer_user_id
		WHERE r.family_id = ?`
	args := []any{familyID}
	if filter.Status != "" {
		query += ` AND r.status = ?`
		args = append(args, filter.Status)
	}
	if filter.RequesterUserID != "" {
		query += ` AND r.requester_user_id = ?`
		args = append(args, filter.RequesterUserID)
	}
	query += ` ORDER BY r.submitted_at DESC, r.id DESC LIMIT ?`
	args = append(args, filter.Limit)

	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list edit requests: %w", err)
	}
	defer rows.Close()

	items := make([]model.EditRequest, 0)
	for rows.Next() {
		item, err := scanEditRequest(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, *item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate edit requests: %w", err)
	}
	return items, nil
}

func scanEditRequest(scanner rowScanner) (*model.EditRequest, error) {
	var item model.EditRequest
	var targetID, reviewerID sql.NullString
	var baseVersion sql.NullInt64
	var payload []byte
	var reviewedAt sql.NullTime

	if err := scanner.Scan(
		&item.ID, &item.FamilyID, &item.RequesterUserID, &item.RequesterName,
		&item.RequestType, &targetID, &item.TargetName,
		&baseVersion, &payload, &item.Status,
		&reviewerID, &item.ReviewerName, &item.ReviewNote,
		&item.SubmittedAt, &reviewedAt,
	); err != nil {
		return nil, fmt.Errorf("scan edit request: %w", err)
	}
	if targetID.Valid {
		value := targetID.String
		item.TargetPersonID = &value
	}
	if reviewerID.Valid {
		value := reviewerID.String
		item.ReviewerUserID = &value
	}
	if baseVersion.Valid {
		value := int(baseVersion.Int64)
		item.BaseVersion = &value
	}
	if reviewedAt.Valid {
		value := reviewedAt.Time
		item.ReviewedAt = &value
	}
	var raw map[string]any
	if err := json.Unmarshal(payload, &raw); err != nil {
		return nil, fmt.Errorf("decode request payload: %w", err)
	}
	item.Payload = raw
	if item.RequestType == "update_person" {
		if err := json.Unmarshal(payload, &item.Changes); err != nil {
			return nil, fmt.Errorf("decode edit changes: %w", err)
		}
		item.ChangedFields = item.Changes.FieldKeys()
	}
	item.Summary = requestSummary(item.RequestType, raw, item.TargetName)
	return &item, nil
}

func requestSummary(requestType string, payload map[string]any, targetName string) string {
	switch requestType {
	case "create_person":
		surname, _ := payload["surname"].(string)
		givenName, _ := payload["givenName"].(string)
		if surname+givenName != "" {
			return "新增人物：" + surname + givenName
		}
		return "新增人物"
	case "add_parent_child":
		return "添加父母关系"
	case "add_spouse":
		return "添加配偶关系"
	case "update_person":
		if targetName != "" {
			return targetName + " · 资料修改"
		}
		return "资料修改"
	default:
		return requestType
	}
}

func (s *Store) ReviewEditRequest(
	ctx context.Context,
	familyID, requestID, reviewerUserID string,
	approve bool,
	note string,
	meta AuditMeta,
) (*model.EditRequest, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin edit review: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var (
		targetID    sql.NullString
		baseVersion sql.NullInt64
		payload     []byte
		status      string
		requestType string
	)
	err = tx.QueryRowContext(ctx, `
		SELECT target_person_id, base_version, payload, status, request_type
		FROM edit_requests
		WHERE family_id = ? AND id = ?
		LIMIT 1
		FOR UPDATE`, familyID, requestID,
	).Scan(&targetID, &baseVersion, &payload, &status, &requestType)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock edit request: %w", err)
	}
	if status != "pending" {
		return nil, ErrConflict
	}

	var action, entityType, entityID string
	var beforeData, afterData []byte
	if approve {
		switch requestType {
		case "update_person":
			if !targetID.Valid || !baseVersion.Valid {
				return nil, ErrVersionConflict
			}
			changes := model.PersonEditChanges{}
			if err := json.Unmarshal(payload, &changes); err != nil {
				return nil, fmt.Errorf("decode edit changes: %w", err)
			}
			before, err := lockEditablePerson(ctx, tx, familyID, targetID.String)
			if err != nil {
				return nil, err
			}
			if before.Version != int(baseVersion.Int64) {
				return nil, ErrVersionConflict
			}
			updates, args, nextValues := buildPersonUpdates(changes)
			if len(updates) == 0 {
				return nil, ErrNoChanges
			}
			args = append(args, targetID.String, familyID, before.Version)
			updates = append(updates, "version = version + 1")
			query := `UPDATE persons SET ` + strings.Join(updates, ", ") +
				` WHERE id = ? AND family_id = ? AND version = ? AND status = 'active'`
			result, err := tx.ExecContext(ctx, query, args...)
			if err != nil {
				return nil, fmt.Errorf("apply edit request: %w", err)
			}
			affected, err := result.RowsAffected()
			if err != nil {
				return nil, fmt.Errorf("edit rows affected: %w", err)
			}
			if affected != 1 {
				return nil, ErrVersionConflict
			}
			beforeData, afterData, err = personAuditJSON(before, nextValues)
			if err != nil {
				return nil, err
			}
			action = "edit_request.approved"
			entityType = "person"
			entityID = targetID.String

		case "create_person":
			var input NewPerson
			if err := json.Unmarshal(payload, &input); err != nil {
				return nil, fmt.Errorf("decode person request: %w", err)
			}
			personID, after, err := insertPersonTx(ctx, tx, familyID, input)
			if err != nil {
				return nil, err
			}
			action = "edit_request.approved"
			entityType = "person"
			entityID = personID
			afterData = after

		case "add_parent_child":
			var input ParentChildInput
			if err := json.Unmarshal(payload, &input); err != nil {
				return nil, fmt.Errorf("decode parent-child request: %w", err)
			}
			edge, after, err := addParentChildTx(ctx, tx, familyID, input)
			if err != nil {
				return nil, err
			}
			action = "edit_request.approved"
			entityType = "parent_child_relationship"
			entityID = edge.ID
			afterData = after

		case "add_spouse":
			var input SpouseInput
			if err := json.Unmarshal(payload, &input); err != nil {
				return nil, fmt.Errorf("decode spouse request: %w", err)
			}
			edge, after, err := addSpouseTx(ctx, tx, familyID, input)
			if err != nil {
				return nil, err
			}
			action = "edit_request.approved"
			entityType = "spouse_relationship"
			entityID = edge.ID
			afterData = after

		default:
			return nil, ErrInvalidRequest
		}
	} else {
		beforeData = payload
		afterData, _ = json.Marshal(map[string]any{
			"status":     "rejected",
			"reviewNote": note,
		})
		action = "edit_request.rejected"
		entityType = "edit_request"
		entityID = requestID
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE edit_requests
		SET status = ?, reviewer_user_id = ?, review_note = ?, reviewed_at = UTC_TIMESTAMP(6)
		WHERE id = ? AND family_id = ? AND status = 'pending'`,
		map[bool]string{true: "approved", false: "rejected"}[approve],
		reviewerUserID, note, requestID, familyID,
	); err != nil {
		return nil, fmt.Errorf("update edit request review: %w", err)
	}
	if err := insertAudit(ctx, tx, familyID, reviewerUserID, action, entityType, entityID, requestID, beforeData, afterData, meta); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit edit review: %w", err)
	}
	return s.GetEditRequest(ctx, familyID, requestID)
}

func lockEditablePerson(ctx context.Context, tx *sql.Tx, familyID, personID string) (*editablePerson, error) {
	var person editablePerson
	err := tx.QueryRowContext(ctx, `
		SELECT full_name, birth_place, residence, occupation, education, biography, version, status
		FROM persons
		WHERE family_id = ? AND id = ?
		LIMIT 1
		FOR UPDATE`, familyID, personID,
	).Scan(
		&person.FullName, &person.BirthPlace, &person.Residence,
		&person.Occupation, &person.Education, &person.Biography,
		&person.Version, &person.Status,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock person: %w", err)
	}
	if person.Status != "active" {
		return nil, ErrNotFound
	}
	return &person, nil
}

func buildPersonUpdates(changes model.PersonEditChanges) ([]string, []any, map[string]string) {
	updates := make([]string, 0, 5)
	args := make([]any, 0, 5)
	values := make(map[string]string, 5)
	add := func(column string, value *string) {
		if value == nil {
			return
		}
		updates = append(updates, column+" = ?")
		args = append(args, *value)
		values[column] = *value
	}
	add("birth_place", changes.BirthPlace)
	add("residence", changes.Residence)
	add("occupation", changes.Occupation)
	add("education", changes.Education)
	add("biography", changes.Biography)
	return updates, args, values
}

func personAuditJSON(before *editablePerson, changed map[string]string) ([]byte, []byte, error) {
	beforeMap := map[string]any{
		"birthPlace": before.BirthPlace,
		"residence":  before.Residence,
		"occupation": before.Occupation,
		"education":  before.Education,
		"biography":  before.Biography,
		"version":    before.Version,
	}
	afterMap := map[string]any{
		"birthPlace": before.BirthPlace,
		"residence":  before.Residence,
		"occupation": before.Occupation,
		"education":  before.Education,
		"biography":  before.Biography,
		"version":    before.Version + 1,
	}
	for column, value := range changed {
		switch column {
		case "birth_place":
			afterMap["birthPlace"] = value
		case "residence":
			afterMap["residence"] = value
		case "occupation":
			afterMap["occupation"] = value
		case "education":
			afterMap["education"] = value
		case "biography":
			afterMap["biography"] = value
		}
	}
	beforeData, err := json.Marshal(beforeMap)
	if err != nil {
		return nil, nil, fmt.Errorf("encode audit before: %w", err)
	}
	afterData, err := json.Marshal(afterMap)
	if err != nil {
		return nil, nil, fmt.Errorf("encode audit after: %w", err)
	}
	return beforeData, afterData, nil
}

func insertAudit(
	ctx context.Context,
	tx *sql.Tx,
	familyID, actorUserID, action, entityType, entityID, requestID string,
	beforeData, afterData []byte,
	meta AuditMeta,
) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO audit_logs
			(family_id, actor_user_id, action, entity_type, entity_id,
			 edit_request_id, before_data, after_data, ip, user_agent, trace_id)
		VALUES (?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''),
		        NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''))`,
		familyID, actorUserID, action, entityType, entityID, requestID,
		string(beforeData), string(afterData), meta.IP, meta.UserAgent, meta.TraceID,
	)
	if err != nil {
		return fmt.Errorf("insert audit log: %w", err)
	}
	return nil
}
