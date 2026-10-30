package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/43374166/family-genealogy/server/internal/store"
)

type joinFamilyPayload struct {
	InviteCode string `json:"inviteCode"`
}

func (a *API) joinFamily(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload joinFamilyPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.InviteCode = strings.ToUpper(strings.TrimSpace(payload.InviteCode))
	if len(payload.InviteCode) < 6 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_INVITE", "a valid invite code is required")
		return
	}
	membership, family, err := a.Store.JoinFamilyWithInvite(
		r.Context(), principal.User.ID, payload.InviteCode, auditMeta(r),
	)
	if err != nil {
		switch {
		case errors.Is(err, store.ErrNotFound):
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_INVITE", "invite code is invalid or expired")
		case errors.Is(err, store.ErrConflict):
			writeProblem(w, r, http.StatusConflict, "ALREADY_MEMBER", "this account is already a member of that family")
		default:
			a.writeAccessError(w, r, err)
		}
		return
	}
	if _, _, err := a.Store.SwitchSessionFamily(
		r.Context(), principal.SessionID, principal.User.ID, family.ID,
	); err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	families, err := a.Store.ListUserFamilies(r.Context(), principal.User.ID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, model.Me{
		User:       principal.User,
		Membership: *membership,
		Family:     *family,
		Families:   families,
	})
}
