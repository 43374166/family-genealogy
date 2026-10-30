package httpapi

import (
	"net/http"
	"strconv"
)

func (a *API) listActivity(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	items, err := a.Store.ListActivities(r.Context(), principal.Family.ID, limit)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}
