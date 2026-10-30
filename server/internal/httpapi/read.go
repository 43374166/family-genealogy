package httpapi

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/43374166/family-genealogy/server/internal/store"
	"github.com/go-chi/chi/v5"
)

type personPage struct {
	Items      []model.PersonSummary `json:"items"`
	NextCursor *string               `json:"nextCursor"`
}

func (a *API) getFamily(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	writeJSON(w, http.StatusOK, principal.Family)
}

func (a *API) getTree(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}

	generation := 0
	if raw := strings.TrimSpace(r.URL.Query().Get("generation")); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil || value < 1 || value > 99 {
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_GENERATION", "generation must be between 1 and 99")
			return
		}
		generation = value
	}
	tree, err := a.Store.GetTree(
		r.Context(), principal.Family.ID, generation, strings.TrimSpace(r.URL.Query().Get("branchId")),
	)
	if err != nil {
		a.writeStoreError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, tree)
}

func (a *API) listPersons(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}

	query := r.URL.Query()
	filter := store.PersonFilter{
		Query:    strings.TrimSpace(query.Get("q")),
		BranchID: strings.TrimSpace(query.Get("branchId")),
		Cursor:   strings.TrimSpace(query.Get("cursor")),
		Limit:    20,
	}
	if len([]rune(filter.Query)) > 80 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "QUERY_TOO_LONG", "q must be at most 80 characters")
		return
	}
	if raw := strings.TrimSpace(query.Get("generation")); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil || value < 1 || value > 99 {
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_GENERATION", "generation must be between 1 and 99")
			return
		}
		filter.Generation = value
	}
	if raw := strings.TrimSpace(query.Get("limit")); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil || value < 1 || value > 100 {
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_LIMIT", "limit must be between 1 and 100")
			return
		}
		filter.Limit = value
	}

	persons, next, err := a.Store.ListPersons(r.Context(), principal.Family.ID, filter)
	if err != nil {
		a.writeStoreError(w, r, err)
		return
	}
	page := personPage{Items: persons}
	if next != "" {
		page.NextCursor = &next
	}
	writeJSON(w, http.StatusOK, page)
}

func (a *API) getPerson(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	personID := strings.TrimSpace(chi.URLParam(r, "personID"))
	if personID == "" {
		writeProblem(w, r, http.StatusNotFound, "PERSON_NOT_FOUND", "person not found")
		return
	}
	person, err := a.Store.GetPerson(r.Context(), principal.Family.ID, personID)
	if err != nil {
		a.writeStoreError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, person)
}

func (a *API) writeStoreError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		writeProblem(w, r, http.StatusNotFound, "NOT_FOUND", "resource not found")
	case errors.Is(err, store.ErrUnauthorized):
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
	default:
		logError(a.Logger, r, "read request failed", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
	}
}
