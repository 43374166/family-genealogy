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
)

type registerRequest struct {
	LoginName   string `json:"loginName"`
	Password    string `json:"password"`
	DisplayName string `json:"displayName"`
	Phone       string `json:"phone"`
	InviteCode  string `json:"inviteCode"`
}

type createInviteRequest struct {
	Role          string `json:"role"`
	BranchID      string `json:"branchId"`
	MaxUses       int    `json:"maxUses"`
	ExpiresInDays int    `json:"expiresInDays"`
}

type bindingPayload struct {
	PersonID string `json:"personId"`
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
	if payload.LoginName == "" || len([]rune(payload.LoginName)) > 80 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_LOGIN_NAME", "loginName is required")
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
	if len(payload.InviteCode) < 6 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVITE_REQUIRED", "a valid invite code is required")
		return
	}
	passwordHash, err := auth.HashPassword(payload.Password)
	if err != nil {
		a.Logger.ErrorContext(r.Context(), "registration password hash failed", "error", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	user, family, err := a.Store.RegisterWithInvite(r.Context(), store.RegisterInput{
		LoginName: payload.LoginName, DisplayName: payload.DisplayName,
		Phone: payload.Phone, PasswordHash: passwordHash,
		InviteCode: payload.InviteCode,
	})
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
