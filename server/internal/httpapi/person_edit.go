package httpapi

import (
	"net/http"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/store"
	"github.com/go-chi/chi/v5"
)

type updatePersonPayload struct {
	Surname          string `json:"surname"`
	GivenName        string `json:"givenName"`
	CourtesyName     string `json:"courtesyName"`
	Alias            string `json:"alias"`
	Gender           string `json:"gender"`
	GenerationNo     int    `json:"generationNo"`
	BranchID         string `json:"branchId"`
	BirthOrder       *int   `json:"birthOrder"`
	BirthYear        *int   `json:"birthYear"`
	BirthMonth       *int   `json:"birthMonth"`
	BirthDay         *int   `json:"birthDay"`
	BirthCalendar    string `json:"birthCalendar"`
	BirthIsLeapMonth bool   `json:"birthIsLeapMonth"`
	DeathYear        *int   `json:"deathYear"`
	DeathMonth       *int   `json:"deathMonth"`
	DeathDay         *int   `json:"deathDay"`
	DeathCalendar    string `json:"deathCalendar"`
	DeathIsLeapMonth bool   `json:"deathIsLeapMonth"`
	LifeStatus       string `json:"lifeStatus"`
	BirthPlace       string `json:"birthPlace"`
	Residence        string `json:"residence"`
	Occupation       string `json:"occupation"`
	Education        string `json:"education"`
	Biography        string `json:"biography"`
	Version          int    `json:"version"`
}

func (a *API) updatePerson(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canWrite(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "WRITE_FORBIDDEN", "only an owner or admin can edit directly")
		return
	}
	var payload updatePersonPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Surname = strings.TrimSpace(payload.Surname)
	payload.GivenName = strings.TrimSpace(payload.GivenName)
	payload.CourtesyName = strings.TrimSpace(payload.CourtesyName)
	payload.Alias = strings.TrimSpace(payload.Alias)
	payload.BranchID = strings.TrimSpace(payload.BranchID)
	payload.BirthPlace = strings.TrimSpace(payload.BirthPlace)
	payload.Residence = strings.TrimSpace(payload.Residence)
	payload.Occupation = strings.TrimSpace(payload.Occupation)
	payload.Education = strings.TrimSpace(payload.Education)
	payload.Biography = strings.TrimSpace(payload.Biography)
	if err := validateNewPerson(createPersonPayload{
		Surname: payload.Surname, GivenName: payload.GivenName,
		CourtesyName: payload.CourtesyName, Alias: payload.Alias,
		Gender: payload.Gender, GenerationNo: payload.GenerationNo,
		BranchID: payload.BranchID, BirthOrder: payload.BirthOrder,
		BirthYear: payload.BirthYear, Biography: payload.Biography,
	}); err != nil {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_PERSON", err.Error())
		return
	}
	if payload.Version < 1 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_VERSION", "version is required")
		return
	}
	if payload.LifeStatus != "living" && payload.LifeStatus != "deceased" && payload.LifeStatus != "unknown" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_LIFE_STATUS", "invalid life status")
		return
	}
	if payload.DeathYear != nil && payload.LifeStatus != "deceased" {
		payload.DeathYear = nil
	}
	if payload.DeathYear != nil && (*payload.DeathYear < 1 || *payload.DeathYear > 9999) {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_DEATH_YEAR", "deathYear must be between 1 and 9999")
		return
	}
	if len([]rune(payload.BirthPlace)) > 160 || len([]rune(payload.Residence)) > 160 ||
		len([]rune(payload.Occupation)) > 160 || len([]rune(payload.Education)) > 160 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "FIELD_TOO_LONG", "one or more fields are too long")
		return
	}
	personID := strings.TrimSpace(chi.URLParam(r, "personID"))
	currentBranch, err := a.Store.PersonBranch(r.Context(), principal.Family.ID, personID)
	if err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	if err := a.ensureBranchScope(
		r.Context(), principal, []string{currentBranch, payload.BranchID},
	); err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	person, err := a.Store.UpdatePerson(
		r.Context(), principal.Family.ID, principal.User.ID, personID,
		store.UpdatePersonInput{
			Surname: payload.Surname, GivenName: payload.GivenName,
			CourtesyName: payload.CourtesyName, Alias: payload.Alias,
			Gender: payload.Gender, GenerationNo: payload.GenerationNo,
			BranchID: payload.BranchID, BirthOrder: payload.BirthOrder,
			BirthYear: payload.BirthYear, BirthMonth: payload.BirthMonth,
			BirthDay: payload.BirthDay, BirthCalendar: payload.BirthCalendar,
			BirthIsLeapMonth: payload.BirthIsLeapMonth,
			DeathYear:        payload.DeathYear, DeathMonth: payload.DeathMonth,
			DeathDay: payload.DeathDay, DeathCalendar: payload.DeathCalendar,
			DeathIsLeapMonth: payload.DeathIsLeapMonth,
			LifeStatus:       payload.LifeStatus, BirthPlace: payload.BirthPlace,
			Residence: payload.Residence, Occupation: payload.Occupation,
			Education: payload.Education, Biography: payload.Biography,
			Version: payload.Version,
		},
		auditMeta(r),
	)
	if err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, person)
}

func (a *API) deleteParentChild(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canWrite(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "WRITE_FORBIDDEN", "only an owner or admin can correct relationships")
		return
	}
	edgeID := strings.TrimSpace(chi.URLParam(r, "edgeID"))
	branchID, err := a.Store.ParentChildEdgeBranch(
		r.Context(), principal.Family.ID, edgeID,
	)
	if err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	if err := a.ensureBranchScope(
		r.Context(), principal, []string{branchID},
	); err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	if err := a.Store.DeleteParentChild(
		r.Context(), principal.Family.ID, principal.User.ID, edgeID, auditMeta(r),
	); err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) deleteSpouse(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canWrite(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "WRITE_FORBIDDEN", "only an owner or admin can correct relationships")
		return
	}
	edgeID := strings.TrimSpace(chi.URLParam(r, "edgeID"))
	branches, err := a.Store.SpouseEdgeBranches(
		r.Context(), principal.Family.ID, edgeID,
	)
	if err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	if err := a.ensureBranchScope(r.Context(), principal, branches); err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	if err := a.Store.DeleteSpouse(
		r.Context(), principal.Family.ID, principal.User.ID, edgeID, auditMeta(r),
	); err != nil {
		a.writeWriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
