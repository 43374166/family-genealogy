package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

func (s *Store) ListStories(ctx context.Context, familyID string, limit int) ([]model.Story, error) {
	if limit < 1 || limit > 100 {
		limit = 50
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT st.id, st.family_id, st.author_user_id, u.display_name,
		       st.person_id, COALESCE(p.full_name, ''), st.title, st.body,
		       st.created_at, st.updated_at
		FROM family_stories st
		JOIN users u ON u.id = st.author_user_id
		LEFT JOIN persons p ON p.id = st.person_id AND p.family_id = st.family_id
		WHERE st.family_id = ? AND st.status = 'active'
		ORDER BY st.created_at DESC, st.id DESC
		LIMIT ?`, familyID, limit)
	if err != nil {
		return nil, fmt.Errorf("list stories: %w", err)
	}
	defer rows.Close()
	items := make([]model.Story, 0)
	for rows.Next() {
		item, err := scanStory(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, *item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate stories: %w", err)
	}
	if err := s.attachStoryPhotos(ctx, familyID, items); err != nil {
		return nil, err
	}
	return items, nil
}

func (s *Store) GetStory(ctx context.Context, familyID, storyID string) (*model.Story, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT st.id, st.family_id, st.author_user_id, u.display_name,
		       st.person_id, COALESCE(p.full_name, ''), st.title, st.body,
		       st.created_at, st.updated_at
		FROM family_stories st
		JOIN users u ON u.id = st.author_user_id
		LEFT JOIN persons p ON p.id = st.person_id AND p.family_id = st.family_id
		WHERE st.family_id = ? AND st.id = ? AND st.status = 'active'`,
		familyID, storyID)
	item, err := scanStory(row)
	if err != nil {
		return nil, err
	}
	items := []model.Story{*item}
	if err := s.attachStoryPhotos(ctx, familyID, items); err != nil {
		return nil, err
	}
	return &items[0], nil
}

func scanStory(scanner rowScanner) (*model.Story, error) {
	var item model.Story
	var personID sql.NullString
	if err := scanner.Scan(
		&item.ID, &item.FamilyID, &item.AuthorUserID, &item.AuthorName,
		&personID, &item.PersonName, &item.Title, &item.Body,
		&item.CreatedAt, &item.UpdatedAt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("scan story: %w", err)
	}
	if personID.Valid {
		value := personID.String
		item.PersonID = &value
	}
	return &item, nil
}

func (s *Store) CreateStory(
	ctx context.Context,
	familyID, authorUserID, personID, title, body string,
	photoIDs []string,
) (*model.Story, error) {
	title = strings.TrimSpace(title)
	body = strings.TrimSpace(body)
	if err := s.validateStoryPerson(ctx, familyID, personID); err != nil {
		return nil, err
	}
	photoIDs, err := s.validateStoryPhotos(ctx, familyID, photoIDs)
	if err != nil {
		return nil, err
	}
	storyID := uuid.NewString()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin story create: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO family_stories
			(id, family_id, author_user_id, person_id, title, body)
		VALUES (?, ?, ?, NULLIF(?, ''), ?, ?)`,
		storyID, familyID, authorUserID, personID, title, body,
	); err != nil {
		return nil, fmt.Errorf("insert story: %w", err)
	}
	if err := replaceStoryPhotos(ctx, tx, familyID, storyID, photoIDs); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit story create: %w", err)
	}
	return s.GetStory(ctx, familyID, storyID)
}

func (s *Store) UpdateStory(
	ctx context.Context,
	familyID, storyID, actorUserID, personID, title, body string,
	photoIDs []string,
) (*model.Story, error) {
	authorID, err := s.storyAuthor(ctx, familyID, storyID)
	if err != nil {
		return nil, err
	}
	if authorID != actorUserID {
		if err := s.requireStoryManager(ctx, familyID, actorUserID); err != nil {
			return nil, err
		}
	}
	if err := s.validateStoryPerson(ctx, familyID, personID); err != nil {
		return nil, err
	}
	photoIDs, err = s.validateStoryPhotos(ctx, familyID, photoIDs)
	if err != nil {
		return nil, err
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin story update: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_stories
		SET person_id = NULLIF(?, ''), title = ?, body = ?
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		personID, strings.TrimSpace(title), strings.TrimSpace(body),
		familyID, storyID,
	); err != nil {
		return nil, fmt.Errorf("update story: %w", err)
	}
	if err := replaceStoryPhotos(ctx, tx, familyID, storyID, photoIDs); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit story update: %w", err)
	}
	return s.GetStory(ctx, familyID, storyID)
}

func (s *Store) DeleteStory(ctx context.Context, familyID, storyID, actorUserID string) error {
	authorID, err := s.storyAuthor(ctx, familyID, storyID)
	if err != nil {
		return err
	}
	if authorID != actorUserID {
		if err := s.requireStoryManager(ctx, familyID, actorUserID); err != nil {
			return err
		}
	}
	if _, err := s.db.ExecContext(ctx, `
		UPDATE family_stories SET status = 'deleted'
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, storyID,
	); err != nil {
		return fmt.Errorf("delete story: %w", err)
	}
	return nil
}

func (s *Store) storyAuthor(ctx context.Context, familyID, storyID string) (string, error) {
	var authorID string
	err := s.db.QueryRowContext(ctx, `
		SELECT author_user_id FROM family_stories
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, storyID,
	).Scan(&authorID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("lookup story author: %w", err)
	}
	return authorID, nil
}

func (s *Store) requireStoryManager(ctx context.Context, familyID, userID string) error {
	var role string
	if err := s.db.QueryRowContext(ctx, `
		SELECT role FROM family_memberships
		WHERE family_id = ? AND user_id = ? AND status = 'active'`,
		familyID, userID,
	).Scan(&role); err != nil {
		return ErrForbidden
	}
	if role != "owner" && role != "admin" {
		return ErrForbidden
	}
	return nil
}

func (s *Store) validateStoryPerson(ctx context.Context, familyID, personID string) error {
	if personID == "" {
		return nil
	}
	var exists int
	if err := s.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM persons
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, personID,
	).Scan(&exists); err != nil {
		return fmt.Errorf("check story person: %w", err)
	}
	if exists == 0 {
		return ErrNotFound
	}
	return nil
}

const maxStoryPhotos = 9

func (s *Store) validateStoryPhotos(
	ctx context.Context,
	familyID string,
	photoIDs []string,
) ([]string, error) {
	photoIDs = uniqueStrings(photoIDs)
	if len(photoIDs) > maxStoryPhotos {
		return nil, ErrInvalidRequest
	}
	if len(photoIDs) == 0 {
		return nil, nil
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(photoIDs)), ",")
	args := make([]any, 0, len(photoIDs)+1)
	args = append(args, familyID)
	for _, photoID := range photoIDs {
		args = append(args, photoID)
	}
	var count int
	if err := s.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM family_photos
		WHERE family_id = ? AND status = 'active' AND id IN (`+placeholders+`)`,
		args...,
	).Scan(&count); err != nil {
		return nil, fmt.Errorf("check story photos: %w", err)
	}
	if count != len(photoIDs) {
		return nil, ErrNotFound
	}
	return photoIDs, nil
}

func replaceStoryPhotos(
	ctx context.Context,
	exec notificationExecer,
	familyID, storyID string,
	photoIDs []string,
) error {
	if _, err := exec.ExecContext(ctx, `
		DELETE FROM family_story_photos
		WHERE family_id = ? AND story_id = ?`, familyID, storyID,
	); err != nil {
		return fmt.Errorf("clear story photos: %w", err)
	}
	for index, photoID := range photoIDs {
		if _, err := exec.ExecContext(ctx, `
			INSERT INTO family_story_photos (story_id, photo_id, family_id, sort_order)
			VALUES (?, ?, ?, ?)`, storyID, photoID, familyID, index,
		); err != nil {
			return fmt.Errorf("insert story photo: %w", err)
		}
	}
	return nil
}

func (s *Store) attachStoryPhotos(
	ctx context.Context,
	familyID string,
	stories []model.Story,
) error {
	if len(stories) == 0 {
		return nil
	}
	storyIDs := make([]string, 0, len(stories))
	indexByID := make(map[string]int, len(stories))
	for index := range stories {
		storyIDs = append(storyIDs, stories[index].ID)
		indexByID[stories[index].ID] = index
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(storyIDs)), ",")
	args := make([]any, 0, len(storyIDs)+1)
	args = append(args, familyID)
	for _, storyID := range storyIDs {
		args = append(args, storyID)
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT sp.story_id, `+photoColumns+`
		FROM family_story_photos sp
		JOIN family_photos ph ON ph.id = sp.photo_id AND ph.family_id = sp.family_id
		JOIN users u ON u.id = ph.uploaded_by_user_id
		LEFT JOIN persons p ON p.id = ph.person_id AND p.family_id = ph.family_id
		WHERE sp.family_id = ? AND sp.story_id IN (`+placeholders+`)
		  AND ph.status = 'active'
		ORDER BY sp.story_id, sp.sort_order`, args...)
	if err != nil {
		return fmt.Errorf("list story photos: %w", err)
	}
	defer rows.Close()
	type storyPhotoRow struct {
		storyID string
		photo   model.Photo
	}
	records := make([]storyPhotoRow, 0)
	for rows.Next() {
		var record storyPhotoRow
		var personID sql.NullString
		var takenAt sql.NullTime
		if err := rows.Scan(
			&record.storyID,
			&record.photo.ID, &record.photo.FamilyID, &personID, &record.photo.PersonName,
			&record.photo.UploadedByUserID, &record.photo.UploadedByName, &record.photo.ContentType,
			&record.photo.SizeBytes, &record.photo.Caption, &takenAt, &record.photo.CreatedAt,
		); err != nil {
			return fmt.Errorf("scan story photo: %w", err)
		}
		if personID.Valid {
			value := personID.String
			record.photo.PersonID = &value
		}
		if takenAt.Valid {
			value := takenAt.Time
			record.photo.TakenAt = &value
		}
		records = append(records, record)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate story photos: %w", err)
	}
	photos := make([]model.Photo, len(records))
	for index, record := range records {
		photos[index] = record.photo
	}
	if err := s.attachPhotoPeople(ctx, familyID, photos); err != nil {
		return err
	}
	storyPhoto := make(map[string][]model.Photo, len(stories))
	for index, record := range records {
		storyPhoto[record.storyID] = append(storyPhoto[record.storyID], photos[index])
	}
	for storyID, items := range storyPhoto {
		if index, ok := indexByID[storyID]; ok {
			stories[index].Photos = items
		}
	}
	return nil
}
