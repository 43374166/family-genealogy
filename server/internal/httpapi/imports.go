package httpapi

import (
	"net/http"
	"strings"
)

type createImportPackagePayload struct {
	RootPersonID string `json:"rootPersonId"`
}

type previewImportPackagePayload struct {
	Code string `json:"code"`
}

type importPackagePayload struct {
	Code           string `json:"code"`
	BranchID       string `json:"branchId"`
	RootGeneration int    `json:"rootGeneration"`
	ParentID       string `json:"parentId"`
	ParentRole     string `json:"parentRole"`
}

func (a *API) createImportPackage(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "OWNER_REQUIRED", "only the family owner can export data")
		return
	}
	var payload createImportPackagePayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.RootPersonID = strings.TrimSpace(payload.RootPersonID)
	if payload.RootPersonID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "PERSON_REQUIRED", "rootPersonId is required")
		return
	}
	pkg, err := a.Store.CreateImportPackage(
		r.Context(), principal.Family.ID, principal.User.ID,
		payload.RootPersonID, auditMeta(r),
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, pkg)
}

func (a *API) previewImportPackage(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "OWNER_REQUIRED", "only the family owner can import data")
		return
	}
	var payload previewImportPackagePayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Code = strings.ToUpper(strings.TrimSpace(payload.Code))
	if len(payload.Code) < 6 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_CODE", "a valid import code is required")
		return
	}
	preview, err := a.Store.PreviewImportPackage(r.Context(), payload.Code)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, preview)
}

func (a *API) importPackage(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "OWNER_REQUIRED", "only the family owner can import data")
		return
	}
	var payload importPackagePayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Code = strings.ToUpper(strings.TrimSpace(payload.Code))
	payload.BranchID = strings.TrimSpace(payload.BranchID)
	payload.ParentID = strings.TrimSpace(payload.ParentID)
	payload.ParentRole = strings.TrimSpace(payload.ParentRole)
	if len(payload.Code) < 6 || payload.BranchID == "" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_IMPORT", "code and branchId are required")
		return
	}
	if payload.RootGeneration < 1 || payload.RootGeneration > 99 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_GENERATION", "rootGeneration must be between 1 and 99")
		return
	}
	if payload.ParentID != "" && payload.ParentRole != "father" && payload.ParentRole != "mother" {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_PARENT", "parentRole must be father or mother")
		return
	}
	result, err := a.Store.ImportPackage(
		r.Context(), principal.Family.ID, principal.User.ID,
		payload.Code, payload.BranchID, payload.RootGeneration,
		payload.ParentID, payload.ParentRole, auditMeta(r),
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, result)
}
