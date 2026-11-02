package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

type JoinFamilyOutcome struct {
	Membership       *model.Membership
	Family           *model.Family
	ArchivedFamilies []model.Family
	MergeRequests    []model.FamilyMergeRequest
}

func (s *Store) JoinFamilyWithInvite(
	ctx context.Context,
	userID, inviteCode string,
	meta AuditMeta,
) (*JoinFamilyOutcome, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin family join: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var (
		inviteID, familyID, role string
		branchID                 sql.NullString
		maxUses, used            int
		expiresAt                time.Time
	)
	err = tx.QueryRowContext(ctx, `
		SELECT id, family_id, role, branch_id, max_uses, used_count, expires_at
		FROM family_invites
		WHERE code = ? AND status = 'active'
		  AND expires_at > UTC_TIMESTAMP(6)
		  AND used_count < max_uses
		LIMIT 1 FOR UPDATE`, inviteCode,
	).Scan(&inviteID, &familyID, &role, &branchID, &maxUses, &used, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("lock family invite: %w", err)
	}
	_ = maxUses
	_ = used
	_ = expiresAt

	var existing int
	if err := tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM family_memberships
		WHERE family_id = ? AND user_id = ?`,
		familyID, userID,
	).Scan(&existing); err != nil {
		return nil, fmt.Errorf("check existing membership: %w", err)
	}
	if existing > 0 {
		return nil, ErrConflict
	}
	membershipID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO family_memberships
			(id, family_id, user_id, role, status)
		VALUES (?, ?, ?, ?, 'active')`,
		membershipID, familyID, userID, role,
	); err != nil {
		return nil, fmt.Errorf("insert joined membership: %w", err)
	}
	if role == "admin" && branchID.Valid {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO branch_admin_grants
				(id, family_id, branch_id, user_id, include_descendants, status, granted_by_user_id)
			VALUES (?, ?, ?, ?, 1, 'active', NULL)`,
			uuid.NewString(), familyID, branchID.String, userID,
		); err != nil {
			return nil, fmt.Errorf("insert joined branch grant: %w", err)
		}
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE family_invites SET used_count = used_count + 1 WHERE id = ?`,
		inviteID,
	); err != nil {
		return nil, fmt.Errorf("consume family invite: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"userId": userID, "role": role, "inviteId": inviteID,
	})
	if err := insertAudit(ctx, tx, familyID, userID, "member.joined",
		"user", userID, "", nil, after, meta); err != nil {
		return nil, err
	}

	// A user normally owns the family created at registration. After joining
	// another family that old space is either empty (archive it silently) or
	// holds data worth keeping (ask the target owner to merge it).
	archivedFamilies, mergeRequests, err := handlePreviousFamilies(
		ctx, tx, userID, familyID, meta,
	)
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit family join: %w", err)
	}
	membership, family, err := s.GetMembership(ctx, userID, familyID)
	if err != nil {
		return nil, err
	}
	return &JoinFamilyOutcome{
		Membership:       membership,
		Family:           family,
		ArchivedFamilies: archivedFamilies,
		MergeRequests:    mergeRequests,
	}, nil
}

func handlePreviousFamilies(
	ctx context.Context,
	tx *sql.Tx,
	userID, targetFamilyID string,
	meta AuditMeta,
) ([]model.Family, []model.FamilyMergeRequest, error) {
	rows, err := tx.QueryContext(ctx, `
		SELECT m.family_id, m.role, f.name, f.status
		FROM family_memberships m
		JOIN families f ON f.id = m.family_id
		WHERE m.user_id = ? AND m.status = 'active' AND m.family_id <> ?
		ORDER BY m.joined_at ASC, m.created_at ASC`, userID, targetFamilyID)
	if err != nil {
		return nil, nil, fmt.Errorf("list previous families: %w", err)
	}
	type previousFamily struct {
		id, role, name, status string
	}
	previous := make([]previousFamily, 0)
	for rows.Next() {
		var item previousFamily
		if err := rows.Scan(&item.id, &item.role, &item.name, &item.status); err != nil {
			_ = rows.Close()
			return nil, nil, fmt.Errorf("scan previous family: %w", err)
		}
		previous = append(previous, item)
	}
	if err := rows.Err(); err != nil {
		_ = rows.Close()
		return nil, nil, fmt.Errorf("iterate previous families: %w", err)
	}
	_ = rows.Close()

	archived := make([]model.Family, 0)
	merges := make([]model.FamilyMergeRequest, 0)
	for _, item := range previous {
		if item.role != "owner" || item.status != "active" {
			// Only the owner can offer a family's data for merging. Other
			// memberships stay untouched.
			continue
		}
		var otherMembers, personCount, photoCount, storyCount int
		if err := tx.QueryRowContext(ctx, `
			SELECT
				(SELECT COUNT(*) FROM family_memberships
				 WHERE family_id = ? AND status = 'active' AND user_id <> ?),
				(SELECT COUNT(*) FROM persons
				 WHERE family_id = ? AND status = 'active'),
				(SELECT COUNT(*) FROM family_photos
				 WHERE family_id = ? AND status = 'active'),
				(SELECT COUNT(*) FROM family_stories
				 WHERE family_id = ? AND status = 'active')`,
			item.id, userID, item.id, item.id, item.id,
		).Scan(&otherMembers, &personCount, &photoCount, &storyCount); err != nil {
			return nil, nil, fmt.Errorf("count previous family data: %w", err)
		}
		if otherMembers == 0 && personCount == 0 && photoCount == 0 && storyCount == 0 {
			var family model.Family
			if err := tx.QueryRowContext(ctx, `
				SELECT id, name, surname, motto, region, description, status, version
				FROM families WHERE id = ? AND status = 'active'`, item.id,
			).Scan(
				&family.ID, &family.Name, &family.Surname, &family.Motto,
				&family.Region, &family.Description, &family.Status, &family.Version,
			); err != nil {
				if errors.Is(err, sql.ErrNoRows) {
					continue
				}
				return nil, nil, fmt.Errorf("read archived family: %w", err)
			}
			after, _ := json.Marshal(map[string]any{
				"status": "archived", "reason": "joined_other_family",
			})
			if err := insertAudit(ctx, tx, item.id, userID, "family.archived",
				"family", item.id, "", nil, after, meta); err != nil {
				return nil, nil, err
			}
			if _, err := tx.ExecContext(ctx, `
				UPDATE families SET status = 'archived'
				WHERE id = ? AND status = 'active'`, item.id,
			); err != nil {
				return nil, nil, fmt.Errorf("archive previous family: %w", err)
			}
			if _, err := tx.ExecContext(ctx, `
				UPDATE family_memberships SET status = 'revoked'
				WHERE family_id = ? AND user_id = ? AND status = 'active'`,
				item.id, userID,
			); err != nil {
				return nil, nil, fmt.Errorf("revoke previous membership: %w", err)
			}
			if _, err := tx.ExecContext(ctx, `
				UPDATE branch_admin_grants SET status = 'revoked'
				WHERE family_id = ? AND user_id = ? AND status = 'active'`,
				item.id, userID,
			); err != nil {
				return nil, nil, fmt.Errorf("revoke previous grants: %w", err)
			}
			family.Status = "archived"
			archived = append(archived, family)
			continue
		}
		if personCount == 0 && photoCount == 0 && storyCount == 0 {
			// The family still belongs to other members and has nothing that can
			// be merged, so keep it as it is.
			continue
		}

		var pending int
		if err := tx.QueryRowContext(ctx, `
			SELECT COUNT(*) FROM family_merge_requests
			WHERE source_family_id = ? AND target_family_id = ? AND status = 'pending'`,
			item.id, targetFamilyID,
		).Scan(&pending); err != nil {
			return nil, nil, fmt.Errorf("check pending merge: %w", err)
		}
		if pending > 0 {
			continue
		}
		var targetName, requesterName string
		if err := tx.QueryRowContext(ctx, `
			SELECT name FROM families WHERE id = ?`, targetFamilyID,
		).Scan(&targetName); err != nil {
			return nil, nil, fmt.Errorf("read target family: %w", err)
		}
		if err := tx.QueryRowContext(ctx, `
			SELECT display_name FROM users WHERE id = ?`, userID,
		).Scan(&requesterName); err != nil {
			return nil, nil, fmt.Errorf("read merge requester: %w", err)
		}
		requestID := uuid.NewString()
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO family_merge_requests
				(id, source_family_id, target_family_id, requester_user_id, status)
			VALUES (?, ?, ?, ?, 'pending')`,
			requestID, item.id, targetFamilyID, userID,
		); err != nil {
			return nil, nil, fmt.Errorf("insert merge request: %w", err)
		}
		var ownerID string
		err := tx.QueryRowContext(ctx, `
			SELECT user_id FROM family_memberships
			WHERE family_id = ? AND role = 'owner' AND status = 'active'
			LIMIT 1`, targetFamilyID,
		).Scan(&ownerID)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return nil, nil, fmt.Errorf("read target owner: %w", err)
		}
		if ownerID != "" {
			if err := insertNotification(ctx, tx, ownerID, targetFamilyID,
				"family_merge_request", "收到家族合并申请",
				fmt.Sprintf("%s 申请把「%s」的 %d 位人物、%d 篇故事、%d 张照片合并进当前家族。",
					requesterName, item.name, personCount, storyCount, photoCount),
				"family_merge_request", requestID); err != nil {
				return nil, nil, err
			}
		}
		after, _ := json.Marshal(map[string]any{
			"targetFamilyId": targetFamilyID, "requestId": requestID,
		})
		if err := insertAudit(ctx, tx, item.id, userID, "family.merge_requested",
			"family_merge_request", requestID, "", nil, after, meta); err != nil {
			return nil, nil, err
		}
		merges = append(merges, model.FamilyMergeRequest{
			ID:               requestID,
			SourceFamilyID:   item.id,
			SourceFamilyName: item.name,
			TargetFamilyID:   targetFamilyID,
			TargetFamilyName: targetName,
			RequesterUserID:  userID,
			RequesterName:    requesterName,
			Status:           "pending",
			PersonCount:      personCount,
			StoryCount:       storyCount,
			PhotoCount:       photoCount,
			CreatedAt:        time.Now().UTC(),
		})
	}
	return archived, merges, nil
}
