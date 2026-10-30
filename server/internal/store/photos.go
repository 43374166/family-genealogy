package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

type PhotoFilter struct {
	PersonID string
	Limit    int
}

func (s *Store) CreatePhoto(
	ctx context.Context,
	familyID, uploadedByUserID, personID, objectKey, contentType string,
	size int64,
	caption string,
) (*model.Photo, error) {
	if personID != "" {
		var exists int
		if err := s.db.QueryRowContext(ctx, `
			SELECT COUNT(*) FROM persons
			WHERE family_id = ? AND id = ? AND status = 'active'`,
			familyID, personID,
		).Scan(&exists); err != nil {
			return nil, fmt.Errorf("check photo person: %w", err)
		}
		if exists == 0 {
			return nil, ErrNotFound
		}
	}
	photoID := uuid.NewString()
	if _, err := s.db.ExecContext(ctx, `
		INSERT INTO family_photos
			(id, family_id, person_id, uploaded_by_user_id, object_key,
			 content_type, size_bytes, caption)
		VALUES (?, ?, NULLIF(?, ''), ?, ?, ?, ?, ?)`,
		photoID, familyID, personID, uploadedByUserID, objectKey,
		contentType, size, caption,
	); err != nil {
		return nil, fmt.Errorf("insert photo: %w", err)
	}
	return s.GetPhoto(ctx, familyID, photoID)
}

func (s *Store) ListPhotos(ctx context.Context, familyID string, filter PhotoFilter) ([]model.Photo, error) {
	if filter.Limit < 1 || filter.Limit > 100 {
		filter.Limit = 50
	}
	query := `
		SELECT ph.id, ph.family_id, ph.person_id, COALESCE(p.full_name, ''),
		       ph.uploaded_by_user_id, u.display_name, ph.content_type,
		       ph.size_bytes, ph.caption, ph.created_at
		FROM family_photos ph
		JOIN users u ON u.id = ph.uploaded_by_user_id
		LEFT JOIN persons p ON p.id = ph.person_id AND p.family_id = ph.family_id
		WHERE ph.family_id = ? AND ph.status = 'active'`
	args := []any{familyID}
	if filter.PersonID != "" {
		query += ` AND ph.person_id = ?`
		args = append(args, filter.PersonID)
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
	return items, nil
}

func (s *Store) GetPhoto(ctx context.Context, familyID, photoID string) (*model.Photo, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT ph.id, ph.family_id, ph.person_id, COALESCE(p.full_name, ''),
		       ph.uploaded_by_user_id, u.display_name, ph.content_type,
		       ph.size_bytes, ph.caption, ph.created_at
		FROM family_photos ph
		JOIN users u ON u.id = ph.uploaded_by_user_id
		LEFT JOIN persons p ON p.id = ph.person_id AND p.family_id = ph.family_id
		WHERE ph.family_id = ? AND ph.id = ? AND ph.status = 'active'`,
		familyID, photoID)
	return scanPhoto(row)
}

func scanPhoto(scanner rowScanner) (*model.Photo, error) {
	var item model.Photo
	var personID sql.NullString
	if err := scanner.Scan(
		&item.ID, &item.FamilyID, &personID, &item.PersonName,
		&item.UploadedByUserID, &item.UploadedByName, &item.ContentType,
		&item.SizeBytes, &item.Caption, &item.CreatedAt,
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
	return &item, nil
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
