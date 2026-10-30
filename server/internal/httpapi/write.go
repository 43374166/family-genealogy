package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/store"
	chimw "github.com/go-chi/chi/v5/middleware"
)

type createPersonPayload struct {
	Surname      string `json:"surname"`
	GivenName    string `json:"givenName"`
	CourtesyName string `json:"courtesyName"`
	Alias        string `json:"alias"`
	Gender       string `json:"gender"`
	GenerationNo int    `json:"generationNo"`
	BranchID     string `json:"branchId"`
	BirthOrder   *int   `json:"birthOrder"`
	BirthYear    *int   `json:"birthYear"`
	Biography    string `json:"biography"`
}

type parentChildPayload struct {
	ParentID   string `json:"parentId"`
	ChildID    string `json:"childId"`
	ParentRole string `json:"parentRole"`
}

type spousePayload struct {
	PersonAID string `json:"personAId"`
	PersonBID string `json:"personBId"`
}

func (a *API) listBranches(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	branches, err := a.Store.ListBranches(r.Context(), principal.Family.ID)
	if err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": branches})
}

func (a *API) createPerson(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canWrite(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "WRITE_FORBIDDEN", "only an owner or admin can write directly")
		return
	}
	var payload createPersonPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Surname = strings.TrimSpace(payload.Surname)
	payload.GivenName = strings.TrimSpace(payload.GivenName)
	payload.CourtesyName = strings.TrimSpace(payload.CourtesyName)
	payload.Alias = strings.TrimSpace(payload.Alias)
	payload.BranchID = strings.TrimSpace(payload.BranchID)
	payload.Biography = strings.TrimSpace(payload.Biography)
	if err := validateNewPerson(payload); err != nil {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_PERSON", err.Error())
		return
	}
	if err := a.ensureBranchScope(
		r.Context(), principal, []string{payload.BranchID},
	); err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	person, err := a.Store.CreatePerson(
		r.Context(), principal.Family.ID, principal.User.ID,
		store.NewPerson{
			Surname: payload.Surname, GivenName: payload.GivenName,
			CourtesyName: payload.CourtesyName, Alias: payload.Alias,
			Gender: payload.Gender, GenerationNo: payload.GenerationNo,
			BranchID: payload.BranchID, BirthOrder: payload.BirthOrder,
			BirthYear: payload.BirthYear, Biography: payload.Biography,
		},
		auditMeta(r),
	)
	if err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, person)
}

func (a *API) addParentChild(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canWrite(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "WRITE_FORBIDDEN", "only an owner or admin can write directly")
		return
	}
	var payload parentChildPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.ParentID = strings.TrimSpace(payload.ParentID)
	payload.ChildID = strings.TrimSpace(payload.ChildID)
	payload.ParentRole = strings.TrimSpace(payload.ParentRole)
	if payload.ParentID == "" || payload.ChildID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_RELATIONSHIP", "parentId and childId are required")
		return
	}
	if payload.ParentRole != "father" && payload.ParentRole != "mother" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_RELATIONSHIP", "parentRole must be father or mother")
		return
	}
	childBranch, err := a.Store.PersonBranch(
		r.Context(), principal.Family.ID, payload.ChildID,
	)
	if err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	if err := a.ensureBranchScope(
		r.Context(), principal, []string{childBranch},
	); err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	edge, err := a.Store.AddParentChild(
		r.Context(), principal.Family.ID, principal.User.ID,
		store.ParentChildInput{
			ParentID: payload.ParentID, ChildID: payload.ChildID,
			ParentRole: payload.ParentRole,
		},
		auditMeta(r),
	)
	if err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, edge)
}

func (a *API) addSpouse(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canWrite(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "WRITE_FORBIDDEN", "only an owner or admin can write directly")
		return
	}
	var payload spousePayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.PersonAID = strings.TrimSpace(payload.PersonAID)
	payload.PersonBID = strings.TrimSpace(payload.PersonBID)
	if payload.PersonAID == "" || payload.PersonBID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_RELATIONSHIP", "personAId and personBId are required")
		return
	}
	branches := make([]string, 0, 2)
	for _, personID := range []string{payload.PersonAID, payload.PersonBID} {
		branchID, err := a.Store.PersonBranch(
			r.Context(), principal.Family.ID, personID,
		)
		if err != nil {
			a.writeWriteError(w, r, err)
			return
		}
		branches = append(branches, branchID)
	}
	if err := a.ensureBranchScope(r.Context(), principal, branches); err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	edge, err := a.Store.AddSpouse(
		r.Context(), principal.Family.ID, principal.User.ID,
		store.SpouseInput{PersonAID: payload.PersonAID, PersonBID: payload.PersonBID},
		auditMeta(r),
	)
	if err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, edge)
}

func canWrite(role string) bool {
	return role == "owner" || role == "admin"
}

func validateNewPerson(payload createPersonPayload) error {
	if len([]rune(payload.Surname)) < 1 || len([]rune(payload.Surname)) > 20 {
		return errors.New("surname must be between 1 and 20 characters")
	}
	if len([]rune(payload.GivenName)) < 1 || len([]rune(payload.GivenName)) > 60 {
		return errors.New("givenName must be between 1 and 60 characters")
	}
	if len([]rune(payload.CourtesyName)) > 60 || len([]rune(payload.Alias)) > 120 {
		return errors.New("courtesyName or alias is too long")
	}
	switch payload.Gender {
	case "male", "female", "other", "unknown":
	default:
		return errors.New("invalid gender")
	}
	if payload.GenerationNo < 1 || payload.GenerationNo > 99 {
		return errors.New("generationNo must be between 1 and 99")
	}
	if payload.BranchID == "" {
		return errors.New("branchId is required")
	}
	if payload.BirthOrder != nil && *payload.BirthOrder < 1 {
		return errors.New("birthOrder must be positive")
	}
	if payload.BirthYear != nil && (*payload.BirthYear < 1 || *payload.BirthYear > 9999) {
		return errors.New("birthYear must be between 1 and 9999")
	}
	if len([]rune(payload.Biography)) > 20000 {
		return errors.New("biography is too long")
	}
	return nil
}

func auditMeta(r *http.Request) store.AuditMeta {
	return store.AuditMeta{
		IP:        clientIP(r),
		UserAgent: truncate(r.UserAgent(), 512),
		TraceID:   truncate(chimw.GetReqID(r.Context()), 128),
	}
}

func (a *API) writeWriteError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		writeProblem(w, r, http.StatusNotFound, "PERSON_OR_BRANCH_NOT_FOUND", "person or branch not found")
	case errors.Is(err, store.ErrConflict):
		writeProblem(w, r, http.StatusConflict, "RELATIONSHIP_CONFLICT", "relationship already exists or role is taken")
	case errors.Is(err, store.ErrCycle):
		writeProblem(w, r, http.StatusUnprocessableEntity, "RELATIONSHIP_CYCLE", "relationship would create a cycle")
	case errors.Is(err, store.ErrInvalidRelationship):
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_RELATIONSHIP", "relationship is not valid for this family")
	case errors.Is(err, store.ErrForbidden):
		writeProblem(w, r, http.StatusForbidden, "BRANCH_SCOPE_FORBIDDEN", "this branch is outside your admin scope")
	default:
		logError(a.Logger, r, "write operation failed", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
	}
}
