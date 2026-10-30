package httpapi

import (
	"net/http"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/43374166/family-genealogy/server/internal/store"
)

type createFamilyPayload struct {
	Name        string `json:"name"`
	Surname     string `json:"surname"`
	Motto       string `json:"motto"`
	Region      string `json:"region"`
	Description string `json:"description"`
}

type switchFamilyPayload struct {
	FamilyID string `json:"familyId"`
}

func (a *API) listFamilies(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	items, err := a.Store.ListUserFamilies(r.Context(), principal.User.ID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (a *API) createFamily(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload createFamilyPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Name = strings.TrimSpace(payload.Name)
	payload.Surname = strings.TrimSpace(payload.Surname)
	payload.Motto = strings.TrimSpace(payload.Motto)
	payload.Region = strings.TrimSpace(payload.Region)
	payload.Description = strings.TrimSpace(payload.Description)
	if payload.Name == "" || len([]rune(payload.Name)) > 80 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_FAMILY_NAME", "family name is required")
		return
	}
	if payload.Surname == "" || len([]rune(payload.Surname)) > 20 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_SURNAME", "surname is required")
		return
	}
	if len([]rune(payload.Motto)) > 200 || len([]rune(payload.Region)) > 120 ||
		len([]rune(payload.Description)) > 2000 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "FAMILY_TOO_LONG", "family fields are too long")
		return
	}
	membership, family, err := a.Store.CreateFamilyForUser(
		r.Context(), principal.User.ID,
		store.NewFamily{
			Name: payload.Name, Surname: payload.Surname,
			Motto: payload.Motto, Region: payload.Region,
			Description: payload.Description,
		},
		auditMeta(r),
	)
	if err != nil {
		a.writeAccessError(w, r, err)
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
	writeJSON(w, http.StatusCreated, model.Me{
		User:       principal.User,
		Membership: *membership,
		Family:     *family,
		Families:   families,
	})
}

func (a *API) switchFamily(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload switchFamilyPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.FamilyID = strings.TrimSpace(payload.FamilyID)
	if payload.FamilyID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "FAMILY_REQUIRED", "familyId is required")
		return
	}
	membership, family, err := a.Store.SwitchSessionFamily(
		r.Context(), principal.SessionID, principal.User.ID, payload.FamilyID,
	)
	if err != nil {
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
