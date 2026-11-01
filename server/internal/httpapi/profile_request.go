package httpapi

import (
	"net/http"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/store"
)

type createProfileRequestPayload struct {
	PersonID         string `json:"personId"`
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

func (a *API) createProfileRequest(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload createProfileRequestPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.PersonID = strings.TrimSpace(payload.PersonID)
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
	if payload.PersonID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "TARGET_REQUIRED", "personId is required")
		return
	}
	if payload.Version < 1 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_VERSION", "version is required")
		return
	}
	if err := validateNewPerson(createPersonPayload{
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
		LifeStatus:       payload.LifeStatus, Biography: payload.Biography,
	}); err != nil {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_PERSON", err.Error())
		return
	}
	if payload.LifeStatus != "living" && payload.LifeStatus != "deceased" && payload.LifeStatus != "unknown" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_LIFE_STATUS", "invalid life status")
		return
	}
	if payload.LifeStatus != "deceased" {
		payload.DeathYear = nil
		payload.DeathMonth, payload.DeathDay = nil, nil
		payload.DeathCalendar, payload.DeathIsLeapMonth = "", false
	}
	request, err := a.Store.CreateProfileRequest(
		r.Context(), principal.Family.ID, principal.User.ID, payload.PersonID,
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
	)
	if err != nil {
		a.writeEditRequestError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, request)
}
