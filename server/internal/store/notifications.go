package store

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/43374166/family-genealogy/server/internal/model"
)

type notificationExecer interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

func insertNotification(
	ctx context.Context,
	exec notificationExecer,
	userID, familyID, kind, title, body, targetType, targetID string,
) error {
	if userID == "" {
		return nil
	}
	_, err := exec.ExecContext(ctx, `
		INSERT INTO notifications
			(user_id, family_id, kind, title, body, target_type, target_id)
		VALUES (?, ?, ?, ?, ?, ?, NULLIF(?, ''))`,
		userID, familyID, kind, title, body, targetType, targetID,
	)
	if err != nil {
		return fmt.Errorf("insert notification: %w", err)
	}
	return nil
}

func notifyReviewers(
	ctx context.Context,
	tx *sql.Tx,
	familyID, excludeUserID, kind, title, body, targetType, targetID string,
) error {
	rows, err := tx.QueryContext(ctx, `
		SELECT user_id FROM family_memberships
		WHERE family_id = ? AND status = 'active'
		  AND role IN ('owner', 'admin') AND user_id <> ?`,
		familyID, excludeUserID)
	if err != nil {
		return fmt.Errorf("list notification reviewers: %w", err)
	}
	defer rows.Close()
	reviewers := make([]string, 0)
	for rows.Next() {
		var userID string
		if err := rows.Scan(&userID); err != nil {
			return fmt.Errorf("scan notification reviewer: %w", err)
		}
		reviewers = append(reviewers, userID)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate notification reviewers: %w", err)
	}
	for _, userID := range reviewers {
		if err := insertNotification(ctx, tx, userID, familyID, kind, title, body, targetType, targetID); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) ListNotifications(
	ctx context.Context, userID, familyID string, limit int,
) ([]model.Notification, int, error) {
	if limit < 1 || limit > 100 {
		limit = 50
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, kind, title, body, target_type, target_id, is_read, created_at
		FROM notifications
		WHERE user_id = ? AND family_id = ?
		ORDER BY created_at DESC, id DESC
		LIMIT ?`, userID, familyID, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("list notifications: %w", err)
	}
	defer rows.Close()
	items := make([]model.Notification, 0)
	for rows.Next() {
		var (
			item     model.Notification
			targetID sql.NullString
		)
		if err := rows.Scan(
			&item.ID, &item.Kind, &item.Title, &item.Body,
			&item.TargetType, &targetID, &item.IsRead, &item.CreatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan notification: %w", err)
		}
		if targetID.Valid {
			value := targetID.String
			item.TargetID = &value
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("iterate notifications: %w", err)
	}
	unread, err := s.UnreadNotificationCount(ctx, userID, familyID)
	if err != nil {
		return nil, 0, err
	}
	return items, unread, nil
}

func (s *Store) UnreadNotificationCount(ctx context.Context, userID, familyID string) (int, error) {
	var count int
	if err := s.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM notifications
		WHERE user_id = ? AND family_id = ? AND is_read = 0`,
		userID, familyID,
	).Scan(&count); err != nil {
		return 0, fmt.Errorf("count unread notifications: %w", err)
	}
	return count, nil
}

func (s *Store) MarkNotificationsRead(
	ctx context.Context, userID, familyID string, notificationID int64, all bool,
) error {
	if all {
		_, err := s.db.ExecContext(ctx, `
			UPDATE notifications SET is_read = 1
			WHERE user_id = ? AND family_id = ? AND is_read = 0`,
			userID, familyID)
		if err != nil {
			return fmt.Errorf("mark all notifications read: %w", err)
		}
		return nil
	}
	if notificationID <= 0 {
		return ErrInvalidRequest
	}
	_, err := s.db.ExecContext(ctx, `
		UPDATE notifications SET is_read = 1
		WHERE id = ? AND user_id = ? AND family_id = ?`,
		notificationID, userID, familyID)
	if err != nil {
		return fmt.Errorf("mark notification read: %w", err)
	}
	return nil
}
