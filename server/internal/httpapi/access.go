package httpapi

import (
	"context"
	"errors"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/43374166/family-genealogy/server/internal/auth"
	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/43374166/family-genealogy/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type registerRequest struct {
	LoginName   string `json:"loginName"`
	Password    string `json:"password"`
	DisplayName string `json:"displayName"`
	Phone       string `json:"phone"`
	InviteCode  string `json:"inviteCode"`
	FamilyName  string `json:"familyName"`
	Surname     string `json:"surname"`
	AcceptTerms *bool  `json:"acceptTerms"`
}

const currentTermsVersion = "2026-10-31"

type createInviteRequest struct {
	Role          string `json:"role"`
	BranchID      string `json:"branchId"`
	MaxUses       int    `json:"maxUses"`
	ExpiresInDays int    `json:"expiresInDays"`
}

type bindingPayload struct {
	PersonID string `json:"personId"`
}

type branchAdminPayload struct {
	UserID             string `json:"userId"`
	BranchID           string `json:"branchId"`
	IncludeDescendants bool   `json:"includeDescendants"`
}

var phonePattern = regexp.MustCompile(`^\+[1-9][0-9]{7,14}$`)

func (a *API) register(w http.ResponseWriter, r *http.Request) {
	var payload registerRequest
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.LoginName = strings.TrimSpace(payload.LoginName)
	payload.DisplayName = strings.TrimSpace(payload.DisplayName)
	payload.Phone = strings.TrimSpace(payload.Phone)
	payload.InviteCode = strings.ToUpper(strings.TrimSpace(payload.InviteCode))
	payload.FamilyName = strings.TrimSpace(payload.FamilyName)
	payload.Surname = strings.TrimSpace(payload.Surname)
	if payload.LoginName == "" || len([]rune(payload.LoginName)) > 80 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_LOGIN_NAME", "loginName is required")
		return
	}
	if payload.AcceptTerms != nil && !*payload.AcceptTerms {
		writeProblem(w, r, http.StatusUnprocessableEntity, "TERMS_REQUIRED", "please accept the user agreement and privacy policy")
		return
	}
	if len(payload.Password) < 8 || len(payload.Password) > 256 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_PASSWORD", "password must be between 8 and 256 characters")
		return
	}
	if payload.DisplayName == "" || len([]rune(payload.DisplayName)) > 80 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_DISPLAY_NAME", "displayName is required")
		return
	}
	if payload.Phone != "" && !phonePattern.MatchString(payload.Phone) {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_PHONE", "phone must use E.164 format, e.g. +8613800000000")
		return
	}
	if payload.InviteCode != "" && len(payload.InviteCode) < 6 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_INVITE", "invite code is too short")
		return
	}
	passwordHash, err := auth.HashPassword(payload.Password)
	if err != nil {
		a.Logger.ErrorContext(r.Context(), "registration password hash failed", "error", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	registerInput := store.RegisterInput{
		LoginName: payload.LoginName, DisplayName: payload.DisplayName,
		Phone: payload.Phone, PasswordHash: passwordHash,
		InviteCode: payload.InviteCode, TermsVersion: currentTermsVersion,
	}
	var (
		user   *model.User
		family *model.Family
	)
	if payload.InviteCode == "" {
		if payload.FamilyName == "" {
			payload.FamilyName = payload.DisplayName + "的家族"
		}
		if payload.Surname == "" {
			runes := []rune(payload.DisplayName)
			if len(runes) > 0 {
				payload.Surname = string(runes[0])
			} else {
				payload.Surname = "家"
			}
		}
		if len([]rune(payload.FamilyName)) > 80 || len([]rune(payload.Surname)) > 20 {
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_FAMILY", "family name or surname is too long")
			return
		}
		user, family, err = a.Store.RegisterOpen(
			r.Context(), registerInput,
			store.NewFamily{
				Name: payload.FamilyName, Surname: payload.Surname,
			},
		)
	} else {
		user, family, err = a.Store.RegisterWithInvite(
			r.Context(), registerInput,
		)
	}
	if err != nil {
		switch {
		case errors.Is(err, store.ErrNotFound):
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_INVITE", "invite code is invalid or expired")
		case errors.Is(err, store.ErrConflict):
			writeProblem(w, r, http.StatusConflict, "ACCOUNT_TAKEN", "login name or phone is already registered")
		default:
			logError(a.Logger, r, "registration failed", err)
			writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		}
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"user": user, "family": family,
	})
}

type acceptTermsRequest struct {
	Version string `json:"version"`
}

func (a *API) acceptTerms(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload acceptTermsRequest
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if payload.Version != currentTermsVersion {
		writeProblem(w, r, http.StatusUnprocessableEntity, "TERMS_VERSION", "please reload and accept the current terms")
		return
	}
	if err := a.Store.AcceptTerms(r.Context(), principal.User.ID, currentTermsVersion); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) createRecoveryCode(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	code, err := auth.NewRecoveryCode()
	if err != nil {
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	hash, err := auth.HashPassword(code)
	if err != nil {
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	if err := a.Store.SetRecoveryCodeHash(r.Context(), principal.User.ID, hash); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"code": code})
}

type resetPasswordRequest struct {
	LoginName    string `json:"loginName"`
	RecoveryCode string `json:"recoveryCode"`
	NewPassword  string `json:"newPassword"`
}

func (a *API) resetPassword(w http.ResponseWriter, r *http.Request) {
	var payload resetPasswordRequest
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.LoginName = strings.TrimSpace(payload.LoginName)
	payload.RecoveryCode = strings.TrimSpace(payload.RecoveryCode)
	if payload.LoginName == "" || len(payload.NewPassword) < 8 || len(payload.NewPassword) > 256 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_RESET", "valid login name and an 8+ character password are required")
		return
	}
	userID, hash, err := a.Store.RecoveryCodeHash(r.Context(), payload.LoginName)
	if err != nil {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_RECOVERY", "invalid login name or recovery code")
		return
	}
	ok, err := auth.VerifyPassword(hash, payload.RecoveryCode)
	if err != nil || !ok {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_RECOVERY", "invalid login name or recovery code")
		return
	}
	newHash, err := auth.HashPassword(payload.NewPassword)
	if err != nil {
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	if err := a.Store.ResetPasswordWithRecovery(r.Context(), userID, newHash); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type changePasswordRequest struct {
	CurrentPassword string `json:"currentPassword"`
	NewPassword     string `json:"newPassword"`
}

func (a *API) changePassword(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload changePasswordRequest
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if len(payload.NewPassword) < 8 || len(payload.NewPassword) > 256 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_PASSWORD", "new password must be between 8 and 256 characters")
		return
	}
	user, hash, err := a.Store.GetLoginUser(r.Context(), principal.User.LoginName)
	if err != nil || user.ID != principal.User.ID {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "current password is incorrect")
		return
	}
	okPassword, err := auth.VerifyPassword(hash, payload.CurrentPassword)
	if err != nil || !okPassword {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "current password is incorrect")
		return
	}
	newHash, err := auth.HashPassword(payload.NewPassword)
	if err != nil {
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	if err := a.Store.ChangePassword(
		r.Context(), principal.User.ID, principal.SessionID, newHash,
	); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type transferOwnerRequest struct {
	UserID string `json:"userId"`
}

func (a *API) transferFamilyOwner(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "OWNER_REQUIRED", "only the family owner can transfer ownership")
		return
	}
	var payload transferOwnerRequest
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.UserID = strings.TrimSpace(payload.UserID)
	if payload.UserID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "USER_REQUIRED", "userId is required")
		return
	}
	if err := a.Store.TransferFamilyOwner(
		r.Context(), principal.Family.ID, principal.User.ID,
		payload.UserID, auditMeta(r),
	); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type deleteAccountRequest struct {
	Password string `json:"password"`
}

func (a *API) deleteAccount(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload deleteAccountRequest
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	user, hash, err := a.Store.GetLoginUser(r.Context(), principal.User.LoginName)
	if err != nil || user.ID != principal.User.ID {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "password is incorrect")
		return
	}
	okPassword, err := auth.VerifyPassword(hash, payload.Password)
	if err != nil || !okPassword {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "password is incorrect")
		return
	}
	newHash, err := auth.HashPassword(uuid.NewString() + uuid.NewString())
	if err != nil {
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	if err := a.Store.AnonymizeAccount(r.Context(), principal.User.ID, newHash); err != nil {
		if errors.Is(err, store.ErrConflict) {
			writeProblem(w, r, http.StatusConflict, "OWNER_CANNOT_DELETE",
				"please transfer family ownership before deleting this account")
			return
		}
		a.writeAccessError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) createInvite(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "INVITE_FORBIDDEN", "only the owner can create invites")
		return
	}
	var payload createInviteRequest
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Role = strings.TrimSpace(payload.Role)
	payload.BranchID = strings.TrimSpace(payload.BranchID)
	if payload.Role == "" {
		payload.Role = "member"
	}
	if payload.MaxUses == 0 {
		payload.MaxUses = 1
	}
	if payload.ExpiresInDays == 0 {
		payload.ExpiresInDays = 7
	}
	if payload.ExpiresInDays < 1 || payload.ExpiresInDays > 365 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_EXPIRY", "expiresInDays must be between 1 and 365")
		return
	}
	invite, err := a.Store.CreateInvite(
		r.Context(), principal.Family.ID, principal.User.ID,
		store.InviteInput{
			Role: payload.Role, BranchID: payload.BranchID,
			MaxUses:   payload.MaxUses,
			ExpiresAt: time.Now().UTC().AddDate(0, 0, payload.ExpiresInDays),
		},
		auditMeta(r),
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, invite)
}

func (a *API) listInvites(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "INVITE_FORBIDDEN", "only the owner can view invites")
		return
	}
	invites, err := a.Store.ListInvites(r.Context(), principal.Family.ID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": invites})
}

func (a *API) listFamilyAccounts(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "ACCOUNT_FORBIDDEN", "only the owner can view accounts")
		return
	}
	items, err := a.Store.ListFamilyAccounts(r.Context(), principal.Family.ID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (a *API) listBranchAdmins(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "only the owner can manage branch admins")
		return
	}
	items, err := a.Store.ListBranchAdminGrants(r.Context(), principal.Family.ID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (a *API) grantBranchAdmin(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "only the owner can manage branch admins")
		return
	}
	var payload branchAdminPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.UserID = strings.TrimSpace(payload.UserID)
	payload.BranchID = strings.TrimSpace(payload.BranchID)
	if payload.UserID == "" || payload.BranchID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_ASSIGNMENT", "userId and branchId are required")
		return
	}
	grant, err := a.Store.GrantBranchAdmin(
		r.Context(), principal.Family.ID, principal.User.ID,
		payload.UserID, payload.BranchID,
		payload.IncludeDescendants, auditMeta(r),
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, grant)
}

func (a *API) revokeBranchAdmin(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "only the owner can manage branch admins")
		return
	}
	grantID := strings.TrimSpace(chi.URLParam(r, "grantID"))
	if err := a.Store.RevokeBranchAdmin(
		r.Context(), principal.Family.ID, principal.User.ID,
		grantID, auditMeta(r),
	); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "revoked"})
}

func (a *API) createBindingRequest(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload bindingPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.PersonID = strings.TrimSpace(payload.PersonID)
	if payload.PersonID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "PERSON_REQUIRED", "personId is required")
		return
	}
	request, err := a.Store.CreateBindingRequest(
		r.Context(), principal.Family.ID, principal.User.ID, payload.PersonID,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, request)
}

func (a *API) listBindingRequests(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	filter := store.BindingFilter{Limit: 50}
	if status := strings.TrimSpace(r.URL.Query().Get("status")); status != "" {
		switch status {
		case "pending", "approved", "rejected", "cancelled":
			filter.Status = status
		default:
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_STATUS", "invalid request status")
			return
		}
	}
	if raw := strings.TrimSpace(r.URL.Query().Get("limit")); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil || value < 1 || value > 100 {
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_LIMIT", "limit must be between 1 and 100")
			return
		}
		filter.Limit = value
	}
	mine, _ := strconv.ParseBool(strings.TrimSpace(r.URL.Query().Get("mine")))
	if mine || !canReview(principal.Membership.Role) {
		filter.RequesterUserID = principal.User.ID
	}
	items, err := a.Store.ListBindingRequests(r.Context(), principal.Family.ID, filter)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, model.BindingRequestPage{Items: items})
}

func (a *API) approveBindingRequest(w http.ResponseWriter, r *http.Request) {
	a.reviewBindingRequest(w, r, true)
}

func (a *API) rejectBindingRequest(w http.ResponseWriter, r *http.Request) {
	a.reviewBindingRequest(w, r, false)
}

func (a *API) reviewBindingRequest(w http.ResponseWriter, r *http.Request, approve bool) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canReview(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "REVIEW_FORBIDDEN", "only an owner or admin can review bindings")
		return
	}
	var payload reviewEditRequestPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Note = strings.TrimSpace(payload.Note)
	if !approve && payload.Note == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "NOTE_REQUIRED", "a rejection note is required")
		return
	}
	requestID := strings.TrimSpace(chi.URLParam(r, "requestID"))
	binding, err := a.Store.GetBindingRequest(r.Context(), principal.Family.ID, requestID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	branchID, err := a.Store.PersonBranch(r.Context(), principal.Family.ID, binding.PersonID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	if err := a.ensureBranchScope(
		r.Context(), principal, []string{branchID},
	); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	request, err := a.Store.ReviewBindingRequest(
		r.Context(), principal.Family.ID, requestID, principal.User.ID,
		approve, payload.Note, auditMeta(r),
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, request)
}

func (a *API) ensureBranchScope(
	ctx context.Context,
	principal *store.Principal,
	branchIDs []string,
) error {
	if principal.Membership.Role == "owner" {
		return nil
	}
	if len(branchIDs) == 0 {
		return store.ErrForbidden
	}
	for _, branchID := range branchIDs {
		ok, err := a.Store.CanAdminAccessBranch(
			ctx, principal.Family.ID, principal.User.ID, branchID,
		)
		if err != nil {
			return err
		}
		if !ok {
			return store.ErrForbidden
		}
	}
	return nil
}

func (a *API) writeAccessError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		writeProblem(w, r, http.StatusNotFound, "NOT_FOUND", "resource not found")
	case errors.Is(err, store.ErrConflict):
		writeProblem(w, r, http.StatusConflict, "CONFLICT", "resource is already taken")
	case errors.Is(err, store.ErrInvalidRequest):
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_REQUEST", "request is not valid")
	case errors.Is(err, store.ErrForbidden):
		writeProblem(w, r, http.StatusForbidden, "BRANCH_SCOPE_FORBIDDEN", "this branch is outside your admin scope")
	default:
		logError(a.Logger, r, "access operation failed", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
	}
}
