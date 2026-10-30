package httpapi

import (
	"net/http"
	"strings"
)

type relationshipEndRequestPayload struct {
	EdgeType string `json:"edgeType"`
	EdgeID   string `json:"edgeId"`
}

func (a *API) createRelationshipEndRequest(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload relationshipEndRequestPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.EdgeType = strings.TrimSpace(payload.EdgeType)
	payload.EdgeID = strings.TrimSpace(payload.EdgeID)
	if payload.EdgeType != "parent_child" && payload.EdgeType != "spouse" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_EDGE_TYPE", "edgeType must be parent_child or spouse")
		return
	}
	if payload.EdgeID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "EDGE_REQUIRED", "edgeId is required")
		return
	}
	request, err := a.Store.CreateRelationshipEndRequest(
		r.Context(), principal.Family.ID, principal.User.ID,
		payload.EdgeType, payload.EdgeID,
	)
	if err != nil {
		a.writeEditRequestError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, request)
}
