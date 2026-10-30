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
	return scanStory(row)
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
) (*model.Story, error) {
	title = strings.TrimSpace(title)
	body = strings.TrimSpace(body)
	if err := s.validateStoryPerson(ctx, familyID, personID); err != nil {
		return nil, err
	}
	storyID := uuid.NewString()
	if _, err := s.db.ExecContext(ctx, `
		INSERT INTO family_stories
			(id, family_id, author_user_id, person_id, title, body)
		VALUES (?, ?, ?, NULLIF(?, ''), ?, ?)`,
		storyID, familyID, authorUserID, personID, title, body,
	); err != nil {
		return nil, fmt.Errorf("insert story: %w", err)
	}
	return s.GetStory(ctx, familyID, storyID)
}

func (s *Store) UpdateStory(
	ctx context.Context,
	familyID, storyID, actorUserID, personID, title, body string,
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
	if _, err := s.db.ExecContext(ctx, `
		UPDATE family_stories
		SET person_id = NULLIF(?, ''), title = ?, body = ?
		WHERE family_id = ? AND id = ? AND status = 'active'`,
		personID, strings.TrimSpace(title), strings.TrimSpace(body),
		familyID, storyID,
	); err != nil {
		return nil, fmt.Errorf("update story: %w", err)
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
