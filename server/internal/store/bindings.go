package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

type BindingFilter struct {
	Status          string
	RequesterUserID string
	Limit           int
}

func (s *Store) CreateBindingRequest(
	ctx context.Context,
	familyID, requesterUserID, personID string,
) (*model.BindingRequest, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin binding request: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var existingPerson sql.NullString
	err = tx.QueryRowContext(ctx, `
		SELECT person_id FROM family_memberships
		WHERE family_id = ? AND user_id = ? AND status = 'active'
		LIMIT 1 FOR UPDATE`, familyID, requesterUserID,
	).Scan(&existingPerson)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock membership: %w", err)
	}
	if existingPerson.Valid {
		return nil, ErrConflict
	}
	var personExists int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM persons
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, personID,
	).Scan(&personExists); err != nil {
		return nil, fmt.Errorf("check binding person: %w", err)
	}
	if personExists == 0 {
		return nil, ErrNotFound
	}
	var alreadyBound int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM family_memberships
		WHERE family_id = ? AND person_id = ? AND status = 'active'`,
		familyID, personID,
	).Scan(&alreadyBound); err != nil {
		return nil, fmt.Errorf("check person binding: %w", err)
	}
	if alreadyBound > 0 {
		return nil, ErrConflict
	}
	requestID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO person_binding_requests
			(id, family_id, requester_user_id, person_id, status)
		VALUES (?, ?, ?, ?, 'pending')`,
		requestID, familyID, requesterUserID, personID,
	); err != nil {
		if isDuplicateError(err) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("insert binding request: %w", err)
	}
	after, _ := json.Marshal(map[string]any{"personId": personID, "status": "pending"})
	if err := insertAudit(ctx, tx, familyID, requesterUserID, "binding.requested",
		"person_binding_request", requestID, "", nil, after, AuditMeta{}); err != nil {
		return nil, err
	}
	if err := notifyReviewers(ctx, tx, familyID, requesterUserID,
		"binding_request", "新的人物绑定申请", "有新的族谱人物绑定申请待审核",
		"binding_request", requestID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit binding request: %w", err)
	}
	return s.GetBindingRequest(ctx, familyID, requestID)
}

func (s *Store) ListBindingRequests(
	ctx context.Context,
	familyID string,
	filter BindingFilter,
) ([]model.BindingRequest, error) {
	if filter.Limit < 1 || filter.Limit > 100 {
		filter.Limit = 50
	}
	query := `
		SELECT r.id, u.display_name, r.person_id, p.full_name, r.status,
		       COALESCE(rv.display_name, ''), r.review_note, r.submitted_at, r.reviewed_at
		FROM person_binding_requests r
		JOIN users u ON u.id = r.requester_user_id
		JOIN persons p ON p.id = r.person_id AND p.family_id = r.family_id
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
		return nil, fmt.Errorf("list binding requests: %w", err)
	}
	defer rows.Close()
	items := make([]model.BindingRequest, 0)
	for rows.Next() {
		item, err := scanBindingRequest(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, *item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate binding requests: %w", err)
	}
	return items, nil
}

func (s *Store) GetBindingRequest(ctx context.Context, familyID, requestID string) (*model.BindingRequest, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT r.id, u.display_name, r.person_id, p.full_name, r.status,
		       COALESCE(rv.display_name, ''), r.review_note, r.submitted_at, r.reviewed_at
		FROM person_binding_requests r
		JOIN users u ON u.id = r.requester_user_id
		JOIN persons p ON p.id = r.person_id AND p.family_id = r.family_id
		LEFT JOIN users rv ON rv.id = r.reviewer_user_id
		WHERE r.family_id = ? AND r.id = ?`, familyID, requestID)
	return scanBindingRequest(row)
}

func scanBindingRequest(scanner rowScanner) (*model.BindingRequest, error) {
	var item model.BindingRequest
	var reviewedAt sql.NullTime
	if err := scanner.Scan(
		&item.ID, &item.RequesterName, &item.PersonID, &item.PersonName,
		&item.Status, &item.ReviewerName, &item.ReviewNote,
		&item.SubmittedAt, &reviewedAt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("scan binding request: %w", err)
	}
	if reviewedAt.Valid {
		value := reviewedAt.Time
		item.ReviewedAt = &value
	}
	return &item, nil
}

func (s *Store) ReviewBindingRequest(
	ctx context.Context,
	familyID, requestID, reviewerUserID string,
	approve bool,
	note string,
	meta AuditMeta,
) (*model.BindingRequest, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin binding review: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var requesterID, personID, status string
	err = tx.QueryRowContext(ctx, `
		SELECT requester_user_id, person_id, status
		FROM person_binding_requests
		WHERE family_id = ? AND id = ?
		LIMIT 1 FOR UPDATE`, familyID, requestID,
	).Scan(&requesterID, &personID, &status)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock binding request: %w", err)
	}
	if status != "pending" {
		return nil, ErrConflict
	}

	var action string
	var afterData []byte
	if approve {
		var currentPerson sql.NullString
		if err := tx.QueryRowContext(ctx, `
			SELECT person_id FROM family_memberships
			WHERE family_id = ? AND user_id = ? AND status = 'active'
			LIMIT 1 FOR UPDATE`, familyID, requesterID,
		).Scan(&currentPerson); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, ErrNotFound
			}
			return nil, fmt.Errorf("lock binding membership: %w", err)
		}
		if currentPerson.Valid {
			return nil, ErrConflict
		}
		var taken int
		if err := tx.QueryRowContext(ctx, `
			SELECT COUNT(*) FROM family_memberships
			WHERE family_id = ? AND person_id = ? AND status = 'active'`,
			familyID, personID,
		).Scan(&taken); err != nil {
			return nil, fmt.Errorf("check binding person: %w", err)
		}
		if taken > 0 {
			return nil, ErrConflict
		}
		if _, err := tx.ExecContext(ctx, `
			UPDATE family_memberships SET person_id = ?
			WHERE family_id = ? AND user_id = ? AND status = 'active'`,
			personID, familyID, requesterID,
		); err != nil {
			if isDuplicateError(err) {
				return nil, ErrConflict
			}
			return nil, fmt.Errorf("bind membership person: %w", err)
		}
		afterData, _ = json.Marshal(map[string]any{
			"personId": personID, "status": "approved",
		})
		action = "binding.approved"
	} else {
		afterData, _ = json.Marshal(map[string]any{
			"personId": personID, "status": "rejected", "reviewNote": note,
		})
		action = "binding.rejected"
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE person_binding_requests
		SET status = ?, reviewer_user_id = ?, review_note = ?, reviewed_at = UTC_TIMESTAMP(6)
		WHERE id = ? AND family_id = ? AND status = 'pending'`,
		map[bool]string{true: "approved", false: "rejected"}[approve],
		reviewerUserID, note, requestID, familyID,
	); err != nil {
		return nil, fmt.Errorf("update binding review: %w", err)
	}
	if err := insertAudit(ctx, tx, familyID, reviewerUserID, action,
		"person_binding_request", requestID, "", nil, afterData, meta); err != nil {
		return nil, err
	}
	title, body := "人物绑定已通过", "你与族谱人物的绑定申请已通过"
	if !approve {
		title, body = "人物绑定被驳回", "你的人物绑定申请未通过"
	}
	if note != "" {
		body = body + "：" + note
	}
	if err := insertNotification(ctx, tx, requesterID, familyID,
		"binding_request", title, body, "binding_request", requestID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit binding review: %w", err)
	}
	return s.GetBindingRequest(ctx, familyID, requestID)
}
