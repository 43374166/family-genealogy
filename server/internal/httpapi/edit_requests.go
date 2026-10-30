package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/43374166/family-genealogy/server/internal/store"
	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
)

type createEditRequestPayload struct {
	TargetPersonID string                  `json:"targetPersonId"`
	BaseVersion    int                     `json:"baseVersion"`
	Changes        model.PersonEditChanges `json:"changes"`
}

type reviewEditRequestPayload struct {
	Note string `json:"note"`
}

type createWriteRequestPayload struct {
	RequestType string          `json:"requestType"`
	Payload     json.RawMessage `json:"payload"`
}

func canReview(role string) bool {
	return role == "owner" || role == "admin"
}

func (a *API) createEditRequest(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload createEditRequestPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.TargetPersonID = strings.TrimSpace(payload.TargetPersonID)
	if payload.TargetPersonID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "TARGET_REQUIRED", "targetPersonId is required")
		return
	}
	if payload.BaseVersion < 1 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_VERSION", "baseVersion must be positive")
		return
	}
	if err := validateEditChanges(&payload.Changes); err != nil {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_CHANGES", err.Error())
		return
	}
	request, err := a.Store.CreateEditRequest(
		r.Context(), principal.Family.ID, principal.User.ID,
		payload.TargetPersonID, payload.BaseVersion, payload.Changes,
	)
	if err != nil {
		a.writeEditRequestError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, request)
}

func (a *API) createWriteRequest(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var body createWriteRequestPayload
	if err := decodeJSON(w, r, &body); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	body.RequestType = strings.TrimSpace(body.RequestType)
	normalized, err := normalizeWritePayload(body.RequestType, body.Payload)
	if err != nil {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_REQUEST", err.Error())
		return
	}
	request, err := a.Store.CreateWriteRequest(
		r.Context(), principal.Family.ID, principal.User.ID,
		body.RequestType, normalized,
	)
	if err != nil {
		a.writeEditRequestError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, request)
}

func normalizeWritePayload(requestType string, raw json.RawMessage) ([]byte, error) {
	switch requestType {
	case "create_person":
		var payload createPersonPayload
		if err := json.Unmarshal(raw, &payload); err != nil {
			return nil, err
		}
		payload.Surname = strings.TrimSpace(payload.Surname)
		payload.GivenName = strings.TrimSpace(payload.GivenName)
		payload.CourtesyName = strings.TrimSpace(payload.CourtesyName)
		payload.Alias = strings.TrimSpace(payload.Alias)
		payload.BranchID = strings.TrimSpace(payload.BranchID)
		payload.Biography = strings.TrimSpace(payload.Biography)
		if err := validateNewPerson(payload); err != nil {
			return nil, err
		}
		return json.Marshal(store.NewPerson{
			Surname: payload.Surname, GivenName: payload.GivenName,
			CourtesyName: payload.CourtesyName, Alias: payload.Alias,
			Gender: payload.Gender, GenerationNo: payload.GenerationNo,
			BranchID: payload.BranchID, BirthOrder: payload.BirthOrder,
			BirthYear: payload.BirthYear, Biography: payload.Biography,
		})
	case "add_parent_child":
		var payload parentChildPayload
		if err := json.Unmarshal(raw, &payload); err != nil {
			return nil, err
		}
		payload.ParentID = strings.TrimSpace(payload.ParentID)
		payload.ChildID = strings.TrimSpace(payload.ChildID)
		payload.ParentRole = strings.TrimSpace(payload.ParentRole)
		if payload.ParentID == "" || payload.ChildID == "" {
			return nil, errors.New("parentId and childId are required")
		}
		if payload.ParentRole != "father" && payload.ParentRole != "mother" {
			return nil, errors.New("parentRole must be father or mother")
		}
		return json.Marshal(store.ParentChildInput{
			ParentID: payload.ParentID, ChildID: payload.ChildID,
			ParentRole: payload.ParentRole,
		})
	case "add_spouse":
		var payload spousePayload
		if err := json.Unmarshal(raw, &payload); err != nil {
			return nil, err
		}
		payload.PersonAID = strings.TrimSpace(payload.PersonAID)
		payload.PersonBID = strings.TrimSpace(payload.PersonBID)
		if payload.PersonAID == "" || payload.PersonBID == "" {
			return nil, errors.New("personAId and personBId are required")
		}
		return json.Marshal(store.SpouseInput{
			PersonAID: payload.PersonAID, PersonBID: payload.PersonBID,
		})
	default:
		return nil, errors.New("requestType must be create_person, add_parent_child or add_spouse")
	}
}

func (a *API) listEditRequests(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	filter := store.EditRequestFilter{Limit: 50}
	switch status := strings.TrimSpace(r.URL.Query().Get("status")); status {
	case "":
	case "pending", "approved", "rejected", "cancelled":
		filter.Status = status
	default:
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_STATUS", "invalid request status")
		return
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
	requests, err := a.Store.ListEditRequests(r.Context(), principal.Family.ID, filter)
	if err != nil {
		a.writeEditRequestError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, model.EditRequestPage{Items: requests})
}

func (a *API) getEditRequest(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	requestID := strings.TrimSpace(chi.URLParam(r, "requestID"))
	request, err := a.Store.GetEditRequest(r.Context(), principal.Family.ID, requestID)
	if err != nil {
		a.writeEditRequestError(w, r, err)
		return
	}
	if request.RequesterUserID != principal.User.ID && !canReview(principal.Membership.Role) {
		writeProblem(w, r, http.StatusNotFound, "REQUEST_NOT_FOUND", "request not found")
		return
	}
	writeJSON(w, http.StatusOK, request)
}

func (a *API) approveEditRequest(w http.ResponseWriter, r *http.Request) {
	a.reviewEditRequest(w, r, true)
}

func (a *API) rejectEditRequest(w http.ResponseWriter, r *http.Request) {
	a.reviewEditRequest(w, r, false)
}

func (a *API) reviewEditRequest(w http.ResponseWriter, r *http.Request, approve bool) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canReview(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "REVIEW_FORBIDDEN", "only an owner or admin can review requests")
		return
	}
	var payload reviewEditRequestPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Note = strings.TrimSpace(payload.Note)
	if len([]rune(payload.Note)) > 2000 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "NOTE_TOO_LONG", "review note must be at most 2000 characters")
		return
	}
	if !approve && payload.Note == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "NOTE_REQUIRED", "a rejection note is required")
		return
	}
	requestID := strings.TrimSpace(chi.URLParam(r, "requestID"))
	branches, err := a.Store.EditRequestBranches(
		r.Context(), principal.Family.ID, requestID,
	)
	if err != nil {
		a.writeEditRequestError(w, r, err)
		return
	}
	if err := a.ensureBranchScope(r.Context(), principal, branches); err != nil {
		a.writeEditRequestError(w, r, err)
		return
	}
	request, err := a.Store.ReviewEditRequest(
		r.Context(), principal.Family.ID, requestID, principal.User.ID,
		approve, payload.Note,
		store.AuditMeta{
			IP:        clientIP(r),
			UserAgent: truncate(r.UserAgent(), 512),
			TraceID:   truncate(chimw.GetReqID(r.Context()), 128),
		},
	)
	if err != nil {
		a.writeEditRequestError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, request)
}

func (a *API) writeEditRequestError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		writeProblem(w, r, http.StatusNotFound, "REQUEST_NOT_FOUND", "request or target person not found")
	case errors.Is(err, store.ErrVersionConflict):
		writeProblem(w, r, http.StatusConflict, "VERSION_CONFLICT", "the person has changed; refresh and submit again")
	case errors.Is(err, store.ErrConflict):
		writeProblem(w, r, http.StatusConflict, "REQUEST_ALREADY_REVIEWED", "request is no longer pending")
	case errors.Is(err, store.ErrNoChanges):
		writeProblem(w, r, http.StatusUnprocessableEntity, "NO_CHANGES", "the request does not change any field")
	case errors.Is(err, store.ErrInvalidRequest):
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_REQUEST_TYPE", "unsupported request type")
	case errors.Is(err, store.ErrForbidden):
		writeProblem(w, r, http.StatusForbidden, "FORBIDDEN", "operation is not allowed")
	default:
		logError(a.Logger, r, "edit request operation failed", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
	}
}

func validateEditChanges(changes *model.PersonEditChanges) error {
	if changes.Empty() {
		return errors.New("at least one changed field is required")
	}
	fields := []struct {
		name  string
		value *string
		max   int
	}{
		{"birthPlace", changes.BirthPlace, 160},
		{"residence", changes.Residence, 160},
		{"occupation", changes.Occupation, 160},
		{"education", changes.Education, 160},
		{"biography", changes.Biography, 2000},
	}
	for _, field := range fields {
		if field.value == nil {
			continue
		}
		value := strings.TrimSpace(*field.value)
		if len([]rune(value)) > field.max {
			return errors.New(field.name + " is too long")
		}
		*field.value = value
	}
	return nil
}
