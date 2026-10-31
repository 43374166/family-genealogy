package httpapi

import (
	"net/http"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/auth"
	"github.com/43374166/family-genealogy/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

func (a *API) exportFamily(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "OWNER_REQUIRED", "only the owner can export family data")
		return
	}
	familyID := strings.TrimSpace(chi.URLParam(r, "familyID"))
	if familyID != principal.Family.ID {
		writeProblem(w, r, http.StatusForbidden, "FORBIDDEN", "not the active family")
		return
	}
	export, err := a.Store.ExportFamily(r.Context(), familyID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, export)
}

type archiveFamilyRequest struct {
	Password    string `json:"password"`
	ConfirmName string `json:"confirmName"`
}

func (a *API) archiveFamily(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "OWNER_REQUIRED", "only the owner can archive the family")
		return
	}
	familyID := strings.TrimSpace(chi.URLParam(r, "familyID"))
	if familyID != principal.Family.ID {
		writeProblem(w, r, http.StatusForbidden, "FORBIDDEN", "not the active family")
		return
	}
	var payload archiveFamilyRequest
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if strings.TrimSpace(payload.ConfirmName) != principal.Family.Name {
		writeProblem(w, r, http.StatusUnprocessableEntity, "CONFIRM_NAME", "family name does not match")
		return
	}
	user, hash, err := a.Store.GetLoginUser(r.Context(), principal.User.LoginName)
	if err != nil || user.ID != principal.User.ID {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "password is incorrect")
		return
	}
	okPassword, err := auth.VerifyPassword(hash, payload.Password)
	if err != nil || !okPassword {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "password is incorrect")
		return
	}
	newHash, err := auth.HashPassword(uuid.NewString() + uuid.NewString())
	if err != nil {
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	if err := a.Store.ArchiveFamilyAndDeleteAccount(
		r.Context(), familyID, principal.User.ID, newHash, auditMeta(r),
	); err != nil {
		if err == store.ErrConflict {
			writeProblem(w, r, http.StatusConflict, "FAMILY_HAS_MEMBERS",
				"transfer or remove other family members before archiving")
			return
		}
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"archived": true, "accountDeleted": true})
}
