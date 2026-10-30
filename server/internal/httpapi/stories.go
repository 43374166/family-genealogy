package httpapi

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
)

type storyPayload struct {
	Title    string `json:"title"`
	Body     string `json:"body"`
	PersonID string `json:"personId"`
}

func (a *API) listStories(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	items, err := a.Store.ListStories(r.Context(), principal.Family.ID, 100)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (a *API) getStory(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	story, err := a.Store.GetStory(
		r.Context(), principal.Family.ID, strings.TrimSpace(chi.URLParam(r, "storyID")),
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, story)
}

func (a *API) createStory(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload storyPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if msg := validateStoryPayload(&payload); msg != "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_STORY", msg)
		return
	}
	story, err := a.Store.CreateStory(
		r.Context(), principal.Family.ID, principal.User.ID,
		strings.TrimSpace(payload.PersonID), payload.Title, payload.Body,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, story)
}

func (a *API) updateStory(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload storyPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if msg := validateStoryPayload(&payload); msg != "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_STORY", msg)
		return
	}
	story, err := a.Store.UpdateStory(
		r.Context(), principal.Family.ID,
		strings.TrimSpace(chi.URLParam(r, "storyID")), principal.User.ID,
		strings.TrimSpace(payload.PersonID), payload.Title, payload.Body,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, story)
}

func (a *API) deleteStory(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if err := a.Store.DeleteStory(
		r.Context(), principal.Family.ID,
		strings.TrimSpace(chi.URLParam(r, "storyID")), principal.User.ID,
	); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func validateStoryPayload(payload *storyPayload) string {
	payload.Title = strings.TrimSpace(payload.Title)
	payload.Body = strings.TrimSpace(payload.Body)
	if payload.Title == "" {
		return "title is required"
	}
	if len([]rune(payload.Title)) > 120 {
		return "title is too long"
	}
	if payload.Body == "" {
		return "body is required"
	}
	if len([]rune(payload.Body)) > 20000 {
		return "body is too long"
	}
	return ""
}
