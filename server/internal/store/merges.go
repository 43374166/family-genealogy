package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

// MergePhotoObject describes a copied OBS object for one source photo.
type MergePhotoObject struct {
	SourcePhotoID string
	ObjectKey     string
	ContentType   string
	SizeBytes     int64
}

// MergePhotoSource is the source metadata the HTTP layer needs before it can
// copy an object into the target family prefix.
type MergePhotoSource struct {
	PhotoID     string
	ObjectKey   string
	ContentType string
	SizeBytes   int64
}

type MergeReviewInput struct {
	RequestID       string
	TargetFamilyID  string
	ReviewerUserID  string
	Approve         bool
	Note            string
	PersonIDs       []string
	StoryIDs        []string
	PhotoIDs        []string
	TargetBranchID  string
	StartGeneration int
	AttachParentID  string
	PhotoObjects    []MergePhotoObject
}

const mergeRequestSelect = `
	SELECT r.id, r.source_family_id, sf.name, r.target_family_id, tf.name,
	       r.requester_user_id, ru.display_name, r.status,
	       r.reviewer_user_id, COALESCE(rv.display_name, ''), r.review_note,
	       r.selected_person_ids, r.selected_story_ids, r.selected_photo_ids,
	       r.target_branch_id, r.start_generation, r.attach_parent_id,
	       r.created_at, r.reviewed_at,
	       (SELECT COUNT(*) FROM persons p
	        WHERE p.family_id = r.source_family_id AND p.status = 'active'),
	       (SELECT COUNT(*) FROM family_stories st
	        WHERE st.family_id = r.source_family_id AND st.status = 'active'),
	       (SELECT COUNT(*) FROM family_photos ph
	        WHERE ph.family_id = r.source_family_id AND ph.status = 'active')
	FROM family_merge_requests r
	JOIN families sf ON sf.id = r.source_family_id
	JOIN families tf ON tf.id = r.target_family_id
	JOIN users ru ON ru.id = r.requester_user_id
	LEFT JOIN users rv ON rv.id = r.reviewer_user_id`

func (s *Store) ListMergeRequests(
	ctx context.Context, targetFamilyID, status string,
) ([]model.FamilyMergeRequest, error) {
	query := mergeRequestSelect + ` WHERE r.target_family_id = ?`
	args := []any{targetFamilyID}
	if status != "" {
		query += ` AND r.status = ?`
		args = append(args, status)
	}
	query += ` ORDER BY r.created_at DESC, r.id DESC LIMIT 100`
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list merge requests: %w", err)
	}
	defer rows.Close()
	items := make([]model.FamilyMergeRequest, 0)
	for rows.Next() {
		item, err := scanMergeRequest(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, *item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate merge requests: %w", err)
	}
	return items, nil
}

func (s *Store) GetMergeRequest(
	ctx context.Context, targetFamilyID, requestID string,
) (*model.FamilyMergeRequest, error) {
	row := s.db.QueryRowContext(ctx, mergeRequestSelect+
		` WHERE r.target_family_id = ? AND r.id = ?`, targetFamilyID, requestID)
	return scanMergeRequest(row)
}

func scanMergeRequest(scanner rowScanner) (*model.FamilyMergeRequest, error) {
	var item model.FamilyMergeRequest
	var (
		reviewerID, reviewerName sql.NullString
		personJSON, storyJSON    []byte
		photoJSON                []byte
		branchID, attachParentID sql.NullString
		startGeneration          sql.NullInt64
		reviewedAt               sql.NullTime
	)
	if err := scanner.Scan(
		&item.ID, &item.SourceFamilyID, &item.SourceFamilyName,
		&item.TargetFamilyID, &item.TargetFamilyName,
		&item.RequesterUserID, &item.RequesterName, &item.Status,
		&reviewerID, &reviewerName, &item.ReviewNote,
		&personJSON, &storyJSON, &photoJSON,
		&branchID, &startGeneration, &attachParentID,
		&item.CreatedAt, &reviewedAt,
		&item.PersonCount, &item.StoryCount, &item.PhotoCount,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("scan merge request: %w", err)
	}
	if reviewerID.Valid {
		value := reviewerID.String
		item.ReviewerUserID = &value
		item.ReviewerName = reviewerName.String
	}
	item.SelectedPersonIDs = decodeStringJSON(personJSON)
	item.SelectedStoryIDs = decodeStringJSON(storyJSON)
	item.SelectedPhotoIDs = decodeStringJSON(photoJSON)
	if branchID.Valid {
		value := branchID.String
		item.TargetBranchID = &value
	}
	if startGeneration.Valid {
		value := int(startGeneration.Int64)
		item.StartGeneration = &value
	}
	if attachParentID.Valid {
		value := attachParentID.String
		item.AttachParentID = &value
	}
	if reviewedAt.Valid {
		value := reviewedAt.Time
		item.ReviewedAt = &value
	}
	return &item, nil
}

func decodeStringJSON(raw []byte) []string {
	if len(raw) == 0 {
		return nil
	}
	var values []string
	if err := json.Unmarshal(raw, &values); err != nil {
		return nil
	}
	return values
}

func marshalStringJSON(values []string) []byte {
	if len(values) == 0 {
		values = []string{}
	}
	encoded, _ := json.Marshal(values)
	return encoded
}

func (s *Store) GetMergeDetail(
	ctx context.Context, targetFamilyID, requestID string,
) (*model.FamilyMergeDetail, error) {
	request, err := s.GetMergeRequest(ctx, targetFamilyID, requestID)
	if err != nil {
		return nil, err
	}
	detail := &model.FamilyMergeDetail{
		Request:  *request,
		Persons:  make([]model.MergePersonItem, 0),
		Stories:  make([]model.MergeStoryItem, 0),
		Photos:   make([]model.MergePhotoItem, 0),
		Branches: make([]model.Branch, 0),
	}
	personRows, err := s.db.QueryContext(ctx, `
		SELECT p.id, p.full_name, p.generation_no, p.generation_name, p.gender,
		       p.life_status, p.branch_id, COALESCE(b.name, ''), p.birth_year
		FROM persons p
		LEFT JOIN branches b ON b.id = p.branch_id AND b.family_id = p.family_id
		WHERE p.family_id = ? AND p.status = 'active'
		ORDER BY p.generation_no, p.birth_order, p.full_name`, request.SourceFamilyID)
	if err != nil {
		return nil, fmt.Errorf("list merge persons: %w", err)
	}
	defer personRows.Close()
	minGeneration, maxGeneration := 0, 0
	for personRows.Next() {
		var (
			item   model.MergePersonItem
			branch sql.NullString
			birth  sql.NullInt64
		)
		if err := personRows.Scan(
			&item.ID, &item.FullName, &item.GenerationNo, &item.GenerationName,
			&item.Gender, &item.LifeStatus, &branch, &item.BranchName, &birth,
		); err != nil {
			return nil, fmt.Errorf("scan merge person: %w", err)
		}
		if branch.Valid {
			value := branch.String
			item.BranchID = &value
		}
		if birth.Valid {
			value := int(birth.Int64)
			item.BirthYear = &value
		}
		if minGeneration == 0 || item.GenerationNo < minGeneration {
			minGeneration = item.GenerationNo
		}
		if item.GenerationNo > maxGeneration {
			maxGeneration = item.GenerationNo
		}
		detail.Persons = append(detail.Persons, item)
	}
	if err := personRows.Err(); err != nil {
		return nil, fmt.Errorf("iterate merge persons: %w", err)
	}
	detail.MinGeneration = minGeneration
	detail.MaxGeneration = maxGeneration

	storyRows, err := s.db.QueryContext(ctx, `
		SELECT st.id, st.title, COALESCE(p.full_name, ''), st.created_at,
		       (SELECT COUNT(*) FROM family_story_photos sp
		        WHERE sp.story_id = st.id AND sp.family_id = st.family_id)
		FROM family_stories st
		LEFT JOIN persons p ON p.id = st.person_id AND p.family_id = st.family_id
		WHERE st.family_id = ? AND st.status = 'active'
		ORDER BY st.created_at DESC, st.id DESC`, request.SourceFamilyID)
	if err != nil {
		return nil, fmt.Errorf("list merge stories: %w", err)
	}
	defer storyRows.Close()
	for storyRows.Next() {
		var item model.MergeStoryItem
		if err := storyRows.Scan(
			&item.ID, &item.Title, &item.PersonName, &item.CreatedAt, &item.PhotoCount,
		); err != nil {
			return nil, fmt.Errorf("scan merge story: %w", err)
		}
		detail.Stories = append(detail.Stories, item)
	}
	if err := storyRows.Err(); err != nil {
		return nil, fmt.Errorf("iterate merge stories: %w", err)
	}

	photoRows, err := s.db.QueryContext(ctx, `
		SELECT ph.id, ph.caption, ph.created_at,
		       COALESCE(GROUP_CONCAT(p.full_name ORDER BY p.full_name SEPARATOR '、'), '')
		FROM family_photos ph
		LEFT JOIN family_photo_people fpp
		       ON fpp.photo_id = ph.id AND fpp.family_id = ph.family_id
		LEFT JOIN persons p ON p.id = fpp.person_id AND p.family_id = fpp.family_id
		WHERE ph.family_id = ? AND ph.status = 'active'
		GROUP BY ph.id, ph.caption, ph.created_at
		ORDER BY ph.created_at DESC, ph.id DESC`, request.SourceFamilyID)
	if err != nil {
		return nil, fmt.Errorf("list merge photos: %w", err)
	}
	defer photoRows.Close()
	for photoRows.Next() {
		var item model.MergePhotoItem
		var names string
		if err := photoRows.Scan(&item.ID, &item.Caption, &item.CreatedAt, &names); err != nil {
			return nil, fmt.Errorf("scan merge photo: %w", err)
		}
		if names != "" {
			item.PersonNames = strings.Split(names, "、")
		}
		detail.Photos = append(detail.Photos, item)
	}
	if err := photoRows.Err(); err != nil {
		return nil, fmt.Errorf("iterate merge photos: %w", err)
	}

	branches, err := s.ListBranches(ctx, targetFamilyID)
	if err != nil {
		return nil, err
	}
	detail.Branches = branches
	return detail, nil
}

func (s *Store) MergePhotoSources(
	ctx context.Context, targetFamilyID, requestID string, photoIDs []string,
) ([]MergePhotoSource, error) {
	photoIDs = uniqueStrings(photoIDs)
	if len(photoIDs) == 0 {
		return nil, nil
	}
	request, err := s.GetMergeRequest(ctx, targetFamilyID, requestID)
	if err != nil {
		return nil, err
	}
	if request.Status != "pending" {
		return nil, ErrConflict
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(photoIDs)), ",")
	args := make([]any, 0, len(photoIDs)+1)
	args = append(args, request.SourceFamilyID)
	for _, photoID := range photoIDs {
		args = append(args, photoID)
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, object_key, content_type, size_bytes
		FROM family_photos
		WHERE family_id = ? AND status = 'active' AND id IN (`+placeholders+`)`, args...)
	if err != nil {
		return nil, fmt.Errorf("list merge photo sources: %w", err)
	}
	defer rows.Close()
	items := make([]MergePhotoSource, 0, len(photoIDs))
	for rows.Next() {
		var item MergePhotoSource
		if err := rows.Scan(&item.PhotoID, &item.ObjectKey, &item.ContentType, &item.SizeBytes); err != nil {
			return nil, fmt.Errorf("scan merge photo source: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate merge photo sources: %w", err)
	}
	if len(items) != len(photoIDs) {
		return nil, ErrNotFound
	}
	return items, nil
}

func (s *Store) ReviewMergeRequest(
	ctx context.Context,
	input MergeReviewInput,
	meta AuditMeta,
) (*model.FamilyMergeResult, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin merge review: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var sourceFamilyID, status, requesterID string
	if err := tx.QueryRowContext(ctx, `
		SELECT source_family_id, status, requester_user_id
		FROM family_merge_requests
		WHERE id = ? AND target_family_id = ?
		FOR UPDATE`, input.RequestID, input.TargetFamilyID,
	).Scan(&sourceFamilyID, &status, &requesterID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("lock merge request: %w", err)
	}
	if status != "pending" {
		return nil, ErrConflict
	}
	input.Note = strings.TrimSpace(input.Note)
	if len([]rune(input.Note)) > 2000 {
		return nil, ErrInvalidRequest
	}
	if !input.Approve {
		if _, err := tx.ExecContext(ctx, `
			UPDATE family_merge_requests
			SET status = 'rejected', reviewer_user_id = ?, review_note = ?,
			    reviewed_at = UTC_TIMESTAMP(6)
			WHERE id = ?`, input.ReviewerUserID, input.Note, input.RequestID,
		); err != nil {
			return nil, fmt.Errorf("reject merge request: %w", err)
		}
		if err := insertNotification(ctx, tx, requesterID, input.TargetFamilyID,
			"family_merge_rejected", "家族合并申请未通过",
			"族长没有通过旧家族数据的合并申请。"+noteSuffix(input.Note),
			"family_merge_request", input.RequestID); err != nil {
			return nil, err
		}
		after, _ := json.Marshal(map[string]any{"status": "rejected"})
		if err := insertAudit(ctx, tx, input.TargetFamilyID, input.ReviewerUserID,
			"family.merge_rejected", "family_merge_request", input.RequestID,
			"", nil, after, meta); err != nil {
			return nil, err
		}
		if err := tx.Commit(); err != nil {
			return nil, fmt.Errorf("commit merge rejection: %w", err)
		}
		request, err := s.GetMergeRequest(ctx, input.TargetFamilyID, input.RequestID)
		if err != nil {
			return nil, err
		}
		return &model.FamilyMergeResult{Request: *request}, nil
	}

	personIDs := uniqueStrings(input.PersonIDs)
	storyIDs := uniqueStrings(input.StoryIDs)
	photoIDs := uniqueStrings(input.PhotoIDs)
	if len(personIDs)+len(storyIDs)+len(photoIDs) == 0 {
		return nil, ErrInvalidRequest
	}

	targetBranchID, err := s.resolveMergeBranch(ctx, tx, input.TargetFamilyID, input.TargetBranchID)
	if err != nil {
		return nil, err
	}
	attachParentID := strings.TrimSpace(input.AttachParentID)
	attachRole := "parent"
	if attachParentID != "" {
		var gender string
		if err := tx.QueryRowContext(ctx, `
			SELECT gender FROM persons
			WHERE family_id = ? AND id = ? AND status = 'active'`,
			input.TargetFamilyID, attachParentID,
		).Scan(&gender); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, ErrNotFound
			}
			return nil, fmt.Errorf("check merge parent: %w", err)
		}
		switch gender {
		case "male":
			attachRole = "father"
		case "female":
			attachRole = "mother"
		}
	}

	persons, err := s.loadMergePersons(ctx, tx, sourceFamilyID, personIDs)
	if err != nil {
		return nil, err
	}
	startGeneration := input.StartGeneration
	if startGeneration == 0 {
		var maxTargetGeneration int
		if err := tx.QueryRowContext(ctx, `
			SELECT COALESCE(MAX(generation_no), 0) FROM persons
			WHERE family_id = ? AND status = 'active'`, input.TargetFamilyID,
		).Scan(&maxTargetGeneration); err != nil {
			return nil, fmt.Errorf("read target generation: %w", err)
		}
		startGeneration = maxTargetGeneration + 1
	}
	if startGeneration < 1 || startGeneration > 99 {
		return nil, ErrInvalidRequest
	}
	offset := 0
	if len(persons) > 0 {
		minGeneration := persons[0].generationNo
		for _, person := range persons {
			if person.generationNo < minGeneration {
				minGeneration = person.generationNo
			}
		}
		offset = startGeneration - minGeneration
		for _, person := range persons {
			generation := person.generationNo + offset
			if generation < 1 || generation > 99 {
				return nil, ErrInvalidRequest
			}
		}
	}

	importedPersons := len(persons)
	var sourceOtherMembers int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM family_memberships
		WHERE family_id = ? AND status = 'active' AND user_id <> ?`,
		sourceFamilyID, requesterID,
	).Scan(&sourceOtherMembers); err != nil {
		return nil, fmt.Errorf("count merge source members: %w", err)
	}
	// Only keep the avatar object reference when the source family will be
	// archived; otherwise a later avatar change there would delete the shared
	// object and break this copy.
	copyAvatar := sourceOtherMembers == 0
	personMap := make(map[string]string, len(persons))
	for _, person := range persons {
		newID := uuid.NewString()
		personMap[person.id] = newID
		generation := person.generationNo + offset
		result, err := tx.ExecContext(ctx, `
			INSERT INTO persons
				(id, family_id, branch_id, surname, given_name, courtesy_name,
				 alias, gender, generation_no, generation_name, birth_order,
				 birth_year, birth_month, birth_day, birth_calendar,
				 birth_is_leap_month, birth_date_text, death_year, death_month,
				 death_day, death_calendar, death_is_leap_month, death_date_text,
				 life_status, birth_place, residence, occupation, education,
				 biography, avatar_object_key, avatar_content_type, status, version)
			SELECT ?, ?, ?, p.surname, p.given_name, p.courtesy_name,
			       p.alias, p.gender, ?, p.generation_name, p.birth_order,
			       p.birth_year, p.birth_month, p.birth_day, p.birth_calendar,
			       p.birth_is_leap_month, p.birth_date_text, p.death_year,
			       p.death_month, p.death_day, p.death_calendar,
			       p.death_is_leap_month, p.death_date_text, p.life_status,
			       p.birth_place, p.residence, p.occupation, p.education,
			       p.biography,
			       CASE WHEN ? THEN p.avatar_object_key ELSE NULL END,
			       CASE WHEN ? THEN p.avatar_content_type ELSE '' END,
			       'active', 1
			FROM persons p
			WHERE p.family_id = ? AND p.id = ? AND p.status = 'active'`,
			newID, input.TargetFamilyID, targetBranchID, generation,
			copyAvatar, copyAvatar, sourceFamilyID, person.id,
		)
		if err != nil {
			return nil, fmt.Errorf("insert merged person: %w", err)
		}
		affected, _ := result.RowsAffected()
		if affected != 1 {
			return nil, ErrNotFound
		}
	}

	edgeRows, err := tx.QueryContext(ctx, `
		SELECT parent_id, child_id, parent_role, notes
		FROM parent_child_relationships
		WHERE family_id = ? AND status = 'active'`, sourceFamilyID)
	if err != nil {
		return nil, fmt.Errorf("list merge parent-child: %w", err)
	}
	type edge struct{ parentID, childID, role, notes string }
	edges := make([]edge, 0)
	for edgeRows.Next() {
		var item edge
		if err := edgeRows.Scan(&item.parentID, &item.childID, &item.role, &item.notes); err != nil {
			_ = edgeRows.Close()
			return nil, fmt.Errorf("scan merge parent-child: %w", err)
		}
		edges = append(edges, item)
	}
	if err := edgeRows.Err(); err != nil {
		_ = edgeRows.Close()
		return nil, fmt.Errorf("iterate merge parent-child: %w", err)
	}
	_ = edgeRows.Close()
	selectedParents := make(map[string]struct{}, len(edges))
	for _, item := range edges {
		parentID, parentOK := personMap[item.parentID]
		childID, childOK := personMap[item.childID]
		if !parentOK || !childOK {
			continue
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO parent_child_relationships
				(id, family_id, parent_id, child_id, parent_role, status, notes)
			VALUES (?, ?, ?, ?, ?, 'active', ?)`,
			uuid.NewString(), input.TargetFamilyID, parentID, childID, item.role, item.notes,
		); err != nil {
			return nil, fmt.Errorf("insert merged parent-child: %w", err)
		}
		selectedParents[item.childID] = struct{}{}
	}
	if attachParentID != "" {
		for oldID, newID := range personMap {
			if _, hasParent := selectedParents[oldID]; hasParent {
				continue
			}
			if _, err := tx.ExecContext(ctx, `
				INSERT INTO parent_child_relationships
					(id, family_id, parent_id, child_id, parent_role, status, notes)
				VALUES (?, ?, ?, ?, ?, 'active', '')`,
				uuid.NewString(), input.TargetFamilyID, attachParentID, newID, attachRole,
			); err != nil {
				return nil, fmt.Errorf("attach merged root: %w", err)
			}
		}
	}

	spouseRows, err := tx.QueryContext(ctx, `
		SELECT person_a_id, person_b_id, status, start_year, end_year, notes
		FROM spouse_relationships
		WHERE family_id = ? AND status <> 'divorced'`, sourceFamilyID)
	if err != nil {
		return nil, fmt.Errorf("list merge spouses: %w", err)
	}
	type spouseEdge struct {
		personAID, personBID, status string
		startYear, endYear           *int
		notes                        string
	}
	spouses := make([]spouseEdge, 0)
	for spouseRows.Next() {
		var (
			item       spouseEdge
			start, end sql.NullInt64
		)
		if err := spouseRows.Scan(
			&item.personAID, &item.personBID, &item.status, &start, &end, &item.notes,
		); err != nil {
			_ = spouseRows.Close()
			return nil, fmt.Errorf("scan merge spouse: %w", err)
		}
		if start.Valid {
			value := int(start.Int64)
			item.startYear = &value
		}
		if end.Valid {
			value := int(end.Int64)
			item.endYear = &value
		}
		spouses = append(spouses, item)
	}
	if err := spouseRows.Err(); err != nil {
		_ = spouseRows.Close()
		return nil, fmt.Errorf("iterate merge spouses: %w", err)
	}
	_ = spouseRows.Close()
	for _, item := range spouses {
		personAID, okA := personMap[item.personAID]
		personBID, okB := personMap[item.personBID]
		if !okA || !okB {
			continue
		}
		if personAID > personBID {
			personAID, personBID = personBID, personAID
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO spouse_relationships
				(id, family_id, person_a_id, person_b_id, status, start_year, end_year, notes)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			uuid.NewString(), input.TargetFamilyID, personAID, personBID,
			item.status, item.startYear, item.endYear, item.notes,
		); err != nil {
			return nil, fmt.Errorf("insert merged spouse: %w", err)
		}
	}

	importedPhotos := 0
	photoMap := make(map[string]string, len(photoIDs))
	for _, object := range input.PhotoObjects {
		if _, ok := photoMap[object.SourcePhotoID]; ok {
			continue
		}
		var (
			uploaderID  string
			caption     string
			contentType string
			sizeBytes   int64
			takenAt     sql.NullTime
			createdAt   time.Time
			personID    sql.NullString
		)
		if err := tx.QueryRowContext(ctx, `
			SELECT uploaded_by_user_id, caption, content_type, size_bytes,
			       taken_at, created_at, person_id
			FROM family_photos
			WHERE family_id = ? AND id = ? AND status = 'active'`,
			sourceFamilyID, object.SourcePhotoID,
		).Scan(&uploaderID, &caption, &contentType, &sizeBytes, &takenAt, &createdAt, &personID); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, ErrNotFound
			}
			return nil, fmt.Errorf("read merge photo: %w", err)
		}
		if object.ContentType != "" {
			contentType = object.ContentType
		}
		if object.SizeBytes > 0 {
			sizeBytes = object.SizeBytes
		}
		newPhotoID := uuid.NewString()
		primaryPersonID := ""
		if oldID, ok := personMap[personID.String]; ok && personID.Valid {
			primaryPersonID = oldID
		}
		var taken any
		if takenAt.Valid {
			taken = takenAt.Time
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO family_photos
				(id, family_id, person_id, uploaded_by_user_id, object_key,
				 content_type, size_bytes, caption, taken_at, created_at)
			VALUES (?, ?, NULLIF(?, ''), ?, ?, ?, ?, ?, ?, ?)`,
			newPhotoID, input.TargetFamilyID, primaryPersonID, uploaderID,
			object.ObjectKey, contentType, sizeBytes, caption, taken, createdAt,
		); err != nil {
			return nil, fmt.Errorf("insert merged photo: %w", err)
		}
		peopleRows, err := tx.QueryContext(ctx, `
			SELECT person_id FROM family_photo_people
			WHERE family_id = ? AND photo_id = ?`, sourceFamilyID, object.SourcePhotoID)
		if err != nil {
			return nil, fmt.Errorf("list merge photo people: %w", err)
		}
		for peopleRows.Next() {
			var oldPersonID string
			if err := peopleRows.Scan(&oldPersonID); err != nil {
				_ = peopleRows.Close()
				return nil, fmt.Errorf("scan merge photo person: %w", err)
			}
			if newPersonID, ok := personMap[oldPersonID]; ok {
				if _, err := tx.ExecContext(ctx, `
					INSERT INTO family_photo_people (photo_id, person_id, family_id)
					VALUES (?, ?, ?)`, newPhotoID, newPersonID, input.TargetFamilyID,
				); err != nil {
					_ = peopleRows.Close()
					return nil, fmt.Errorf("insert merged photo person: %w", err)
				}
			}
		}
		if err := peopleRows.Err(); err != nil {
			_ = peopleRows.Close()
			return nil, fmt.Errorf("iterate merge photo people: %w", err)
		}
		_ = peopleRows.Close()
		if primaryPersonID != "" {
			if _, err := tx.ExecContext(ctx, `
				INSERT IGNORE INTO family_photo_people (photo_id, person_id, family_id)
				VALUES (?, ?, ?)`, newPhotoID, primaryPersonID, input.TargetFamilyID,
			); err != nil {
				return nil, fmt.Errorf("tag merged primary photo person: %w", err)
			}
		}
		photoMap[object.SourcePhotoID] = newPhotoID
		importedPhotos++
	}
	for _, photoID := range photoIDs {
		if _, ok := photoMap[photoID]; !ok {
			return nil, ErrInvalidRequest
		}
	}

	importedStories := 0
	for _, storyID := range storyIDs {
		var (
			authorID  string
			personID  sql.NullString
			title     string
			body      string
			createdAt time.Time
		)
		if err := tx.QueryRowContext(ctx, `
			SELECT author_user_id, person_id, title, body, created_at
			FROM family_stories
			WHERE family_id = ? AND id = ? AND status = 'active'`,
			sourceFamilyID, storyID,
		).Scan(&authorID, &personID, &title, &body, &createdAt); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, ErrNotFound
			}
			return nil, fmt.Errorf("read merge story: %w", err)
		}
		newStoryID := uuid.NewString()
		newPersonID := ""
		if personID.Valid {
			newPersonID = personMap[personID.String]
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO family_stories
				(id, family_id, author_user_id, person_id, title, body, created_at)
			VALUES (?, ?, ?, NULLIF(?, ''), ?, ?, ?)`,
			newStoryID, input.TargetFamilyID, authorID, newPersonID, title, body, createdAt,
		); err != nil {
			return nil, fmt.Errorf("insert merged story: %w", err)
		}
		storyPhotoRows, err := tx.QueryContext(ctx, `
			SELECT photo_id, sort_order FROM family_story_photos
			WHERE family_id = ? AND story_id = ? ORDER BY sort_order`,
			sourceFamilyID, storyID)
		if err != nil {
			return nil, fmt.Errorf("list merge story photos: %w", err)
		}
		for storyPhotoRows.Next() {
			var sourcePhotoID string
			var sortOrder int
			if err := storyPhotoRows.Scan(&sourcePhotoID, &sortOrder); err != nil {
				_ = storyPhotoRows.Close()
				return nil, fmt.Errorf("scan merge story photo: %w", err)
			}
			if newPhotoID, ok := photoMap[sourcePhotoID]; ok {
				if _, err := tx.ExecContext(ctx, `
					INSERT INTO family_story_photos (story_id, photo_id, family_id, sort_order)
					VALUES (?, ?, ?, ?)`, newStoryID, newPhotoID, input.TargetFamilyID, sortOrder,
				); err != nil {
					_ = storyPhotoRows.Close()
					return nil, fmt.Errorf("insert merged story photo: %w", err)
				}
			}
		}
		if err := storyPhotoRows.Err(); err != nil {
			_ = storyPhotoRows.Close()
			return nil, fmt.Errorf("iterate merge story photos: %w", err)
		}
		_ = storyPhotoRows.Close()
		importedStories++
	}

	personJSON := marshalStringJSON(personIDs)
	storyJSON := marshalStringJSON(storyIDs)
	photoJSON := marshalStringJSON(photoIDs)
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_merge_requests
		SET status = 'approved', reviewer_user_id = ?, review_note = ?,
		    selected_person_ids = ?, selected_story_ids = ?, selected_photo_ids = ?,
		    target_branch_id = ?, start_generation = ?, attach_parent_id = ?,
		    reviewed_at = UTC_TIMESTAMP(6)
		WHERE id = ?`,
		input.ReviewerUserID, input.Note, personJSON, storyJSON, photoJSON,
		targetBranchID, startGeneration, nullIfEmpty(attachParentID), input.RequestID,
	); err != nil {
		return nil, fmt.Errorf("approve merge request: %w", err)
	}

	if err := insertNotification(ctx, tx, requesterID, input.TargetFamilyID,
		"family_merge_approved", "家族合并申请已通过",
		fmt.Sprintf("已合并 %d 位人物、%d 篇故事、%d 张照片到当前家族。", importedPersons, importedStories, importedPhotos)+
			noteSuffix(input.Note),
		"family_merge_request", input.RequestID); err != nil {
		return nil, err
	}
	after, _ := json.Marshal(map[string]any{
		"status": "approved", "persons": importedPersons,
		"stories": importedStories, "photos": importedPhotos,
		"sourceFamilyId": sourceFamilyID,
	})
	if err := insertAudit(ctx, tx, input.TargetFamilyID, input.ReviewerUserID,
		"family.merge_approved", "family_merge_request", input.RequestID,
		"", nil, after, meta); err != nil {
		return nil, err
	}

	sourceArchived := false
	if sourceOtherMembers == 0 {
		if _, err := tx.ExecContext(ctx, `
			UPDATE families SET status = 'archived' WHERE id = ? AND status = 'active'`,
			sourceFamilyID,
		); err != nil {
			return nil, fmt.Errorf("archive merged source family: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `
			UPDATE family_memberships SET status = 'revoked'
			WHERE family_id = ? AND user_id = ? AND status = 'active'`,
			sourceFamilyID, requesterID,
		); err != nil {
			return nil, fmt.Errorf("revoke merged source membership: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `
			UPDATE branch_admin_grants SET status = 'revoked'
			WHERE family_id = ? AND user_id = ? AND status = 'active'`,
			sourceFamilyID, requesterID,
		); err != nil {
			return nil, fmt.Errorf("revoke merged source grants: %w", err)
		}
		archived, _ := json.Marshal(map[string]any{"status": "archived", "reason": "merged"})
		if err := insertAudit(ctx, tx, sourceFamilyID, input.ReviewerUserID,
			"family.archived", "family", sourceFamilyID,
			"", nil, archived, meta); err != nil {
			return nil, err
		}
		sourceArchived = true
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit merge review: %w", err)
	}
	request, err := s.GetMergeRequest(ctx, input.TargetFamilyID, input.RequestID)
	if err != nil {
		return nil, err
	}
	return &model.FamilyMergeResult{
		Request:         *request,
		ImportedPersons: importedPersons,
		ImportedStories: importedStories,
		ImportedPhotos:  importedPhotos,
		SourceArchived:  sourceArchived,
	}, nil
}

func (s *Store) resolveMergeBranch(
	ctx context.Context, tx *sql.Tx, familyID, requested string,
) (string, error) {
	requested = strings.TrimSpace(requested)
	if requested != "" {
		var exists int
		if err := tx.QueryRowContext(ctx, `
			SELECT COUNT(*) FROM branches WHERE family_id = ? AND id = ?`,
			familyID, requested,
		).Scan(&exists); err != nil {
			return "", fmt.Errorf("check merge branch: %w", err)
		}
		if exists == 0 {
			return "", ErrNotFound
		}
		return requested, nil
	}
	var branchID string
	if err := tx.QueryRowContext(ctx, `
		SELECT id FROM branches WHERE family_id = ?
		ORDER BY sort_order ASC, name ASC LIMIT 1`, familyID,
	).Scan(&branchID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", ErrInvalidRequest
		}
		return "", fmt.Errorf("pick merge branch: %w", err)
	}
	return branchID, nil
}

type mergePerson struct {
	id           string
	generationNo int
}

func (s *Store) loadMergePersons(
	ctx context.Context, tx *sql.Tx, familyID string, personIDs []string,
) ([]mergePerson, error) {
	if len(personIDs) == 0 {
		return nil, nil
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(personIDs)), ",")
	args := make([]any, 0, len(personIDs)+1)
	args = append(args, familyID)
	for _, personID := range personIDs {
		args = append(args, personID)
	}
	rows, err := tx.QueryContext(ctx, `
		SELECT id, generation_no FROM persons
		WHERE family_id = ? AND status = 'active' AND id IN (`+placeholders+`)
		ORDER BY generation_no ASC, birth_order ASC, full_name ASC`, args...)
	if err != nil {
		return nil, fmt.Errorf("list merge persons: %w", err)
	}
	defer rows.Close()
	items := make([]mergePerson, 0, len(personIDs))
	for rows.Next() {
		var item mergePerson
		if err := rows.Scan(&item.id, &item.generationNo); err != nil {
			return nil, fmt.Errorf("scan merge person: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate merge persons: %w", err)
	}
	if len(items) != len(personIDs) {
		return nil, ErrNotFound
	}
	return items, nil
}

func noteSuffix(note string) string {
	note = strings.TrimSpace(note)
	if note == "" {
		return ""
	}
	return " 族长备注：" + note
}

func nullIfEmpty(value string) any {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return value
}
