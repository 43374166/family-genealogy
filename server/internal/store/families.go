package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/google/uuid"
)

type NewFamily struct {
	Name        string
	Surname     string
	Motto       string
	Region      string
	Description string
}

func (s *Store) CreateFamilyForUser(
	ctx context.Context,
	userID string,
	input NewFamily,
	meta AuditMeta,
) (*model.Membership, *model.Family, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("begin family creation: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	familyID, membershipID, err := createFamilyTx(
		ctx, tx, userID, input, meta,
	)
	if err != nil {
		return nil, nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, nil, fmt.Errorf("commit family creation: %w", err)
	}
	family, err := s.GetFamily(ctx, familyID)
	if err != nil {
		return nil, nil, err
	}
	var personID sql.NullString
	var joinedAt time.Time
	membership := &model.Membership{
		ID: membershipID, Role: "owner", Status: "active",
	}
	_ = s.db.QueryRowContext(ctx, `
		SELECT person_id, joined_at FROM family_memberships WHERE id = ?`,
		membershipID,
	).Scan(&personID, &joinedAt)
	if personID.Valid {
		value := personID.String
		membership.PersonID = &value
	}
	membership.JoinedAt = joinedAt
	return membership, family, nil
}

func (s *Store) RegisterOpen(
	ctx context.Context,
	input RegisterInput,
	familyInput NewFamily,
) (*model.User, *model.Family, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("begin open registration: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	userID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO users
			(id, login_name, phone, password_hash, display_name, status,
			 terms_accepted_at, terms_version)
		VALUES (?, ?, NULLIF(?, ''), ?, ?, 'active', UTC_TIMESTAMP(6), ?)`,
		userID, input.LoginName, input.Phone, input.PasswordHash, input.DisplayName,
		input.TermsVersion,
	); err != nil {
		if isDuplicateError(err) {
			return nil, nil, ErrConflict
		}
		return nil, nil, fmt.Errorf("insert registered user: %w", err)
	}
	familyID, _, err := createFamilyTx(
		ctx, tx, userID, familyInput, AuditMeta{},
	)
	if err != nil {
		return nil, nil, err
	}
	after, _ := json.Marshal(map[string]any{
		"loginName": input.LoginName, "displayName": input.DisplayName,
		"familyId": familyID,
	})
	if err := insertAudit(ctx, tx, familyID, userID, "member.registered",
		"user", userID, "", nil, after, AuditMeta{}); err != nil {
		return nil, nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, nil, fmt.Errorf("commit open registration: %w", err)
	}
	user := &model.User{
		ID: userID, LoginName: input.LoginName,
		DisplayName: input.DisplayName, Phone: input.Phone, Status: "active",
	}
	family, err := s.GetFamily(ctx, familyID)
	if err != nil {
		return nil, nil, err
	}
	return user, family, nil
}

func createFamilyTx(
	ctx context.Context,
	tx *sql.Tx,
	ownerUserID string,
	input NewFamily,
	meta AuditMeta,
) (string, string, error) {
	familyID := uuid.NewString()
	branchID := uuid.NewString()
	membershipID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO families
			(id, name, surname, motto, region, description, status, version)
		VALUES (?, ?, ?, ?, ?, ?, 'active', 1)`,
		familyID, input.Name, input.Surname, input.Motto,
		input.Region, input.Description,
	); err != nil {
		return "", "", fmt.Errorf("insert family: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO branches
			(id, family_id, name, description, sort_order)
		VALUES (?, ?, '本支', '', 0)`,
		branchID, familyID,
	); err != nil {
		return "", "", fmt.Errorf("insert family branch: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO family_memberships
			(id, family_id, user_id, role, status)
		VALUES (?, ?, ?, 'owner', 'active')`,
		membershipID, familyID, ownerUserID,
	); err != nil {
		return "", "", fmt.Errorf("insert family owner: %w", err)
	}
	after, _ := json.Marshal(map[string]any{
		"familyId": familyID, "name": input.Name, "surname": input.Surname,
	})
	if err := insertAudit(ctx, tx, familyID, ownerUserID, "family.created",
		"family", familyID, "", nil, after, meta); err != nil {
		return "", "", err
	}
	return familyID, membershipID, nil
}
