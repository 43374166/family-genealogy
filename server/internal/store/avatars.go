package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
)

func (s *Store) CanEditPersonAvatar(ctx context.Context, familyID, personID, userID string) (bool, error) {
	var role string
	var linkedPerson sql.NullString
	err := s.db.QueryRowContext(ctx, `
		SELECT role, person_id FROM family_memberships
		WHERE family_id = ? AND user_id = ? AND status = 'active'`,
		familyID, userID,
	).Scan(&role, &linkedPerson)
	if errors.Is(err, sql.ErrNoRows) {
		return false, ErrForbidden
	}
	if err != nil {
		return false, fmt.Errorf("check avatar permission: %w", err)
	}
	if role == "owner" || role == "admin" {
		return true, nil
	}
	return linkedPerson.Valid && linkedPerson.String == personID, nil
}

func (s *Store) PersonAvatarKey(ctx context.Context, familyID, personID string) (string, string, error) {
	var key, contentType string
	err := s.db.QueryRowContext(ctx, `
		SELECT avatar_object_key, avatar_content_type FROM persons
		WHERE family_id = ? AND id = ? AND status = 'active'
		  AND avatar_object_key IS NOT NULL`,
		familyID, personID,
	).Scan(&key, &contentType)
	if errors.Is(err, sql.ErrNoRows) {
		return "", "", ErrNotFound
	}
	if err != nil {
		return "", "", fmt.Errorf("lookup avatar: %w", err)
	}
	return key, contentType, nil
}

func (s *Store) ClearPersonAvatar(ctx context.Context, familyID, personID, userID string) (string, error) {
	if ok, err := s.CanEditPersonAvatar(ctx, familyID, personID, userID); err != nil {
		return "", err
	} else if !ok {
		return "", ErrForbidden
	}
	var oldKey sql.NullString
	if err := s.db.QueryRowContext(ctx, `
		SELECT avatar_object_key FROM persons
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, personID,
	).Scan(&oldKey); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", fmt.Errorf("lookup avatar clear: %w", err)
	}
	if _, err := s.db.ExecContext(ctx, `
		UPDATE persons
		SET avatar_object_key = NULL, avatar_content_type = '', version = version + 1
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		familyID, personID,
	); err != nil {
		return "", fmt.Errorf("clear avatar: %w", err)
	}
	if oldKey.Valid {
		return oldKey.String, nil
	}
	return "", nil
}

func (s *Store) SetPersonAvatar(
	ctx context.Context,
	familyID, personID, userID, objectKey, contentType string,
) (string, error) {
	if ok, err := s.CanEditPersonAvatar(ctx, familyID, personID, userID); err != nil {
		return "", err
	} else if !ok {
		return "", ErrForbidden
	}
	var oldKey sql.NullString
	if err := s.db.QueryRowContext(ctx, `
		SELECT avatar_object_key FROM persons
		WHERE family_id = ? AND id = ? AND status = 'active'
		FOR UPDATE`, familyID, personID,
	).Scan(&oldKey); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", fmt.Errorf("lock avatar person: %w", err)
	}
	if _, err := s.db.ExecContext(ctx, `
		UPDATE persons
		SET avatar_object_key = ?, avatar_content_type = ?, version = version + 1
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		objectKey, contentType, familyID, personID,
	); err != nil {
		return "", fmt.Errorf("update avatar: %w", err)
	}
	if oldKey.Valid {
		return oldKey.String, nil
	}
	return "", nil
}
