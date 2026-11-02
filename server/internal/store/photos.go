package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

type PhotoFilter struct {
	// PersonIDs matches photos tagged with any of the people.
	PersonIDs []string
	// SolePersonID additionally requires the photo to have exactly one tag,
	// which is how the person profile shows only that person's own photos.
	SolePersonID string
	Limit        int
}

const photoColumns = `
	ph.id, ph.family_id, ph.person_id, COALESCE(p.full_name, ''),
	ph.uploaded_by_user_id, u.display_name, ph.content_type,
	ph.size_bytes, ph.caption, ph.taken_at, ph.created_at`

func (s *Store) CreatePhoto(
	ctx context.Context,
	familyID, uploadedByUserID string,
	personIDs []string,
	objectKey, contentType string,
	size int64,
	caption string,
	takenAt *time.Time,
) (*model.Photo, error) {
	personIDs, err := s.validatePhotoPeople(ctx, familyID, personIDs)
	if err != nil {
		return nil, err
	}
	photoID := uuid.NewString()
	primaryPersonID := ""
	if len(personIDs) > 0 {
		primaryPersonID = personIDs[0]
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin photo create: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO family_photos
			(id, family_id, person_id, uploaded_by_user_id, object_key,
			 content_type, size_bytes, caption, taken_at)
		VALUES (?, ?, NULLIF(?, ''), ?, ?, ?, ?, ?, ?)`,
		photoID, familyID, primaryPersonID, uploadedByUserID, objectKey,
		contentType, size, caption, takenAt,
	); err != nil {
		return nil, fmt.Errorf("insert photo: %w", err)
	}
	if err := insertPhotoPeople(ctx, tx, familyID, photoID, personIDs); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit photo create: %w", err)
	}
	return s.GetPhoto(ctx, familyID, photoID)
}

func (s *Store) ListPhotos(ctx context.Context, familyID string, filter PhotoFilter) ([]model.Photo, error) {
	if filter.Limit < 1 || filter.Limit > 100 {
		filter.Limit = 50
	}
	personIDs := uniqueStrings(filter.PersonIDs)
	query := `
		SELECT ` + photoColumns + `
		FROM family_photos ph
		JOIN users u ON u.id = ph.uploaded_by_user_id
		LEFT JOIN persons p ON p.id = ph.person_id AND p.family_id = ph.family_id
		WHERE ph.family_id = ? AND ph.status = 'active'`
	args := []any{familyID}
	if len(personIDs) > 0 {
		placeholders := strings.TrimRight(strings.Repeat("?,", len(personIDs)), ",")
		query += ` AND EXISTS (
			SELECT 1 FROM family_photo_people fpp
			WHERE fpp.photo_id = ph.id AND fpp.family_id = ph.family_id
			  AND fpp.person_id IN (` + placeholders + `))`
		for _, personID := range personIDs {
			args = append(args, personID)
		}
	}
	if solePersonID := strings.TrimSpace(filter.SolePersonID); solePersonID != "" {
		query += ` AND (
			SELECT COUNT(*) FROM family_photo_people fpp
			WHERE fpp.photo_id = ph.id AND fpp.family_id = ph.family_id) = 1
			AND EXISTS (
				SELECT 1 FROM family_photo_people fpp2
				WHERE fpp2.photo_id = ph.id AND fpp2.family_id = ph.family_id
				  AND fpp2.person_id = ?)`
		args = append(args, solePersonID)
	}
	query += ` ORDER BY ph.created_at DESC, ph.id DESC LIMIT ?`
	args = append(args, filter.Limit)
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list photos: %w", err)
	}
	defer rows.Close()
	items := make([]model.Photo, 0)
	for rows.Next() {
		item, err := scanPhoto(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, *item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate photos: %w", err)
	}
	if err := s.attachPhotoPeople(ctx, familyID, items); err != nil {
		return nil, err
	}
	return items, nil
}

func (s *Store) GetPhoto(ctx context.Context, familyID, photoID string) (*model.Photo, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT `+photoColumns+`
		FROM family_photos ph
		JOIN users u ON u.id = ph.uploaded_by_user_id
		LEFT JOIN persons p ON p.id = ph.person_id AND p.family_id = ph.family_id
		WHERE ph.family_id = ? AND ph.id = ? AND ph.status = 'active'`,
		familyID, photoID)
	item, err := scanPhoto(row)
	if err != nil {
		return nil, err
	}
	items := []model.Photo{*item}
	if err := s.attachPhotoPeople(ctx, familyID, items); err != nil {
		return nil, err
	}
	return &items[0], nil
}

func scanPhoto(scanner rowScanner) (*model.Photo, error) {
	var item model.Photo
	var personID sql.NullString
	var takenAt sql.NullTime
	if err := scanner.Scan(
		&item.ID, &item.FamilyID, &personID, &item.PersonName,
		&item.UploadedByUserID, &item.UploadedByName, &item.ContentType,
		&item.SizeBytes, &item.Caption, &takenAt, &item.CreatedAt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("scan photo: %w", err)
	}
	if personID.Valid {
		value := personID.String
		item.PersonID = &value
	}
	if takenAt.Valid {
		value := takenAt.Time
		item.TakenAt = &value
	}
	return &item, nil
}

// attachPhotoPeople fills the multi-person tag list. The legacy person_id is
// kept as a fallback for rows created before the join table existed.
func (s *Store) attachPhotoPeople(ctx context.Context, familyID string, items []model.Photo) error {
	if len(items) == 0 {
		return nil
	}
	photoIDs := make([]string, 0, len(items))
	byID := make(map[string]*model.Photo, len(items))
	for index := range items {
		photoIDs = append(photoIDs, items[index].ID)
		byID[items[index].ID] = &items[index]
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(photoIDs)), ",")
	args := make([]any, 0, len(photoIDs)+1)
	args = append(args, familyID)
	for _, photoID := range photoIDs {
		args = append(args, photoID)
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT fpp.photo_id, fpp.person_id, p.full_name
		FROM family_photo_people fpp
		JOIN persons p ON p.id = fpp.person_id AND p.family_id = fpp.family_id
		WHERE fpp.family_id = ? AND fpp.photo_id IN (`+placeholders+`)
		ORDER BY fpp.created_at ASC, p.full_name ASC`, args...)
	if err != nil {
		return fmt.Errorf("list photo people: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var photoID string
		var person model.PhotoPerson
		if err := rows.Scan(&photoID, &person.PersonID, &person.FullName); err != nil {
			return fmt.Errorf("scan photo person: %w", err)
		}
		if photo := byID[photoID]; photo != nil {
			photo.Persons = append(photo.Persons, person)
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate photo people: %w", err)
	}
	for index := range items {
		item := &items[index]
		if len(item.Persons) == 0 && item.PersonID != nil {
			item.Persons = []model.PhotoPerson{{
				PersonID: *item.PersonID, FullName: item.PersonName,
			}}
		}
	}
	return nil
}

func (s *Store) UpdatePhotoMetadata(
	ctx context.Context,
	familyID, photoID, actorUserID string,
	personIDs []string,
	caption string,
	takenAt *time.Time,
) (*model.Photo, error) {
	personIDs, err := s.validatePhotoPeople(ctx, familyID, personIDs)
	if err != nil {
		return nil, err
	}
	primaryPersonID := ""
	if len(personIDs) > 0 {
		primaryPersonID = personIDs[0]
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin photo update: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	var uploaderID string
	if err := tx.QueryRowContext(ctx, `
		SELECT uploaded_by_user_id FROM family_photos
		WHERE family_id = ? AND id = ? AND status = 'active'
		FOR UPDATE`,
		familyID, photoID,
	).Scan(&uploaderID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("lock photo editor: %w", err)
	}
	if uploaderID != actorUserID {
		var role string
		if err := tx.QueryRowContext(ctx, `
			SELECT role FROM family_memberships
			WHERE family_id = ? AND user_id = ? AND status = 'active'`,
			familyID, actorUserID,
		).Scan(&role); err != nil {
			return nil, ErrForbidden
		}
		if role != "owner" && role != "admin" {
			return nil, ErrForbidden
		}
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_photos
		SET person_id = NULLIF(?, ''), caption = ?, taken_at = ?
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		primaryPersonID, caption, takenAt, familyID, photoID,
	); err != nil {
		return nil, fmt.Errorf("update photo metadata: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		DELETE FROM family_photo_people
		WHERE family_id = ? AND photo_id = ?`, familyID, photoID,
	); err != nil {
		return nil, fmt.Errorf("clear photo people: %w", err)
	}
	if err := insertPhotoPeople(ctx, tx, familyID, photoID, personIDs); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit photo update: %w", err)
	}
	return s.GetPhoto(ctx, familyID, photoID)
}

func (s *Store) validatePhotoPeople(
	ctx context.Context,
	familyID string,
	personIDs []string,
) ([]string, error) {
	personIDs = uniqueStrings(personIDs)
	if len(personIDs) == 0 {
		return nil, nil
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(personIDs)), ",")
	args := make([]any, 0, len(personIDs)+1)
	args = append(args, familyID)
	for _, personID := range personIDs {
		args = append(args, personID)
	}
	var count int
	if err := s.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM persons
		WHERE family_id = ? AND status = 'active' AND id IN (`+placeholders+`)`,
		args...,
	).Scan(&count); err != nil {
		return nil, fmt.Errorf("check photo people: %w", err)
	}
	if count != len(personIDs) {
		return nil, ErrNotFound
	}
	return personIDs, nil
}

func insertPhotoPeople(
	ctx context.Context,
	exec notificationExecer,
	familyID, photoID string,
	personIDs []string,
) error {
	for _, personID := range personIDs {
		if _, err := exec.ExecContext(ctx, `
			INSERT INTO family_photo_people (photo_id, person_id, family_id)
			VALUES (?, ?, ?)`, photoID, personID, familyID,
		); err != nil {
			return fmt.Errorf("insert photo person: %w", err)
		}
	}
	return nil
}

func uniqueStrings(values []string) []string {
	seen := make(map[string]struct{}, len(values))
	result := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}
	return result
}

func (s *Store) PhotoObjectKey(ctx context.Context, familyID, photoID string) (string, error) {
	var key string
	err := s.db.QueryRowContext(ctx, `
		SELECT object_key FROM family_photos
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, photoID,
	).Scan(&key)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("lookup photo object: %w", err)
	}
	return key, nil
}

func (s *Store) DeletePhoto(ctx context.Context, familyID, photoID, actorUserID string) (string, error) {
	var objectKey, uploaderID string
	err := s.db.QueryRowContext(ctx, `
		SELECT object_key, uploaded_by_user_id FROM family_photos
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, photoID,
	).Scan(&objectKey, &uploaderID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("lookup photo delete: %w", err)
	}
	if uploaderID != actorUserID {
		var role string
		if err := s.db.QueryRowContext(ctx, `
			SELECT role FROM family_memberships
			WHERE family_id = ? AND user_id = ? AND status = 'active'`,
			familyID, actorUserID,
		).Scan(&role); err != nil {
			return "", ErrForbidden
		}
		if role != "owner" && role != "admin" {
			return "", ErrForbidden
		}
	}
	if _, err := s.db.ExecContext(ctx, `
		UPDATE family_photos SET status = 'deleted'
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, photoID,
	); err != nil {
		return "", fmt.Errorf("delete photo: %w", err)
	}
	return objectKey, nil
}
