package httpapi

import (
	"net/http"
)

func (a *API) listNotifications(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	items, unread, err := a.Store.ListNotifications(
		r.Context(), principal.User.ID, principal.Family.ID, 50,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"items": items, "unreadCount": unread,
	})
}

func (a *API) unreadNotificationCount(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	count, err := a.Store.UnreadNotificationCount(
		r.Context(), principal.User.ID, principal.Family.ID,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"count": count})
}

type readNotificationsPayload struct {
	ID  int64 `json:"id"`
	All bool  `json:"all"`
}

func (a *API) readNotifications(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload readNotificationsPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if err := a.Store.MarkNotificationsRead(
		r.Context(), principal.User.ID, principal.Family.ID,
		payload.ID, payload.All,
	); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
