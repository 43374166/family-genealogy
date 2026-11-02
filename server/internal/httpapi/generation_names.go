package httpapi

import (
	"net/http"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
)

func (a *API) listGenerationNames(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	items, err := a.Store.ListGenerationNames(r.Context(), principal.Family.ID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

type generationNamesPayload struct {
	Items []model.GenerationName `json:"items"`
}

func (a *API) replaceGenerationNames(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canWrite(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "WRITE_FORBIDDEN", "only an owner or admin can edit generation names")
		return
	}
	var payload generationNamesPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if len(payload.Items) > 99 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "TOO_MANY_GENERATIONS", "too many generations")
		return
	}
	seen := make(map[int]bool, len(payload.Items))
	items := make([]model.GenerationName, 0, len(payload.Items))
	for _, item := range payload.Items {
		item.Name = strings.TrimSpace(item.Name)
		if item.GenerationNo < 1 || item.GenerationNo > 99 {
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_GENERATION", "generationNo must be between 1 and 99")
			return
		}
		if item.Name == "" {
			continue
		}
		if len([]rune(item.Name)) > 20 {
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_NAME", "generation name is too long")
			return
		}
		if seen[item.GenerationNo] {
			writeProblem(w, r, http.StatusUnprocessableEntity, "DUPLICATE_GENERATION", "generationNo is duplicated")
			return
		}
		seen[item.GenerationNo] = true
		items = append(items, item)
	}
	if err := a.Store.ReplaceGenerationNames(
		r.Context(), principal.Family.ID, principal.User.ID, items, auditMeta(r),
	); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}
