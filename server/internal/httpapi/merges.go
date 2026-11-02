package httpapi

import (
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type mergeReviewPayload struct {
	Note            string   `json:"note"`
	PersonIDs       []string `json:"personIds"`
	StoryIDs        []string `json:"storyIds"`
	PhotoIDs        []string `json:"photoIds"`
	TargetBranchID  string   `json:"targetBranchId"`
	StartGeneration int      `json:"startGeneration"`
	AttachParentID  string   `json:"attachParentId"`
}

func (a *API) listFamilyMergeRequests(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canWrite(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "REVIEW_FORBIDDEN", "only an owner or admin can view merge requests")
		return
	}
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	switch status {
	case "", "pending", "approved", "rejected", "cancelled":
	default:
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_STATUS", "invalid request status")
		return
	}
	items, err := a.Store.ListMergeRequests(r.Context(), principal.Family.ID, status)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (a *API) getFamilyMergeDetail(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if !canWrite(principal.Membership.Role) {
		writeProblem(w, r, http.StatusForbidden, "REVIEW_FORBIDDEN", "only an owner or admin can view merge requests")
		return
	}
	detail, err := a.Store.GetMergeDetail(
		r.Context(), principal.Family.ID,
		strings.TrimSpace(chi.URLParam(r, "requestID")),
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, detail)
}

func (a *API) approveFamilyMerge(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "OWNER_REQUIRED", "only the family owner can approve a merge")
		return
	}
	var payload mergeReviewPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.PersonIDs = uniquePhotoIDs(payload.PersonIDs)
	payload.StoryIDs = uniquePhotoIDs(payload.StoryIDs)
	payload.PhotoIDs = uniquePhotoIDs(payload.PhotoIDs)
	if len(payload.PersonIDs)+len(payload.StoryIDs)+len(payload.PhotoIDs) == 0 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "NO_ITEMS", "select at least one person, story or photo")
		return
	}
	if payload.StartGeneration < 0 || payload.StartGeneration > 99 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_GENERATION", "startGeneration must be between 1 and 99")
		return
	}
	requestID := strings.TrimSpace(chi.URLParam(r, "requestID"))
	photoObjects := make([]store.MergePhotoObject, 0, len(payload.PhotoIDs))
	copiedKeys := make([]string, 0, len(payload.PhotoIDs))
	cleanup := func() {
		for _, key := range copiedKeys {
			_ = a.Photos.Delete(r.Context(), key)
		}
	}
	if len(payload.PhotoIDs) > 0 {
		if a.Photos == nil {
			writeProblem(w, r, http.StatusServiceUnavailable, "PHOTOS_UNAVAILABLE", "photo storage is not configured")
			return
		}
		sources, err := a.Store.MergePhotoSources(
			r.Context(), principal.Family.ID, requestID, payload.PhotoIDs,
		)
		if err != nil {
			a.writeAccessError(w, r, err)
			return
		}
		for _, source := range sources {
			body, contentType, size, err := a.Photos.Get(r.Context(), source.ObjectKey)
			if err != nil {
				cleanup()
				logError(a.Logger, r, "merge photo read failed", err)
				writeProblem(w, r, http.StatusBadGateway, "PHOTO_READ_FAILED", "could not read photo")
				return
			}
			data, readErr := io.ReadAll(io.LimitReader(body, maxPhotoBytes+1))
			_ = body.Close()
			if readErr != nil || len(data) == 0 || len(data) > maxPhotoBytes {
				cleanup()
				writeProblem(w, r, http.StatusBadGateway, "PHOTO_READ_FAILED", "could not read photo")
				return
			}
			if contentType == "" {
				contentType = source.ContentType
			}
			extension := ".jpg"
			switch contentType {
			case "image/png":
				extension = ".png"
			case "image/webp":
				extension = ".webp"
			}
			objectKey := a.Photos.ObjectKey(
				principal.Family.ID, "merged/"+uuid.NewString()+extension,
			)
			if err := a.Photos.Put(r.Context(), objectKey, data, contentType); err != nil {
				cleanup()
				logError(a.Logger, r, "merge photo copy failed", err)
				writeProblem(w, r, http.StatusBadGateway, "PHOTO_UPLOAD_FAILED", "could not store photo")
				return
			}
			copiedKeys = append(copiedKeys, objectKey)
			photoObjects = append(photoObjects, store.MergePhotoObject{
				SourcePhotoID: source.PhotoID,
				ObjectKey:     objectKey,
				ContentType:   contentType,
				SizeBytes:     int64(len(data)),
			})
			_ = size
		}
	}
	result, err := a.Store.ReviewMergeRequest(r.Context(), store.MergeReviewInput{
		RequestID:       requestID,
		TargetFamilyID:  principal.Family.ID,
		ReviewerUserID:  principal.User.ID,
		Approve:         true,
		Note:            payload.Note,
		PersonIDs:       payload.PersonIDs,
		StoryIDs:        payload.StoryIDs,
		PhotoIDs:        payload.PhotoIDs,
		TargetBranchID:  payload.TargetBranchID,
		StartGeneration: payload.StartGeneration,
		AttachParentID:  payload.AttachParentID,
		PhotoObjects:    photoObjects,
	}, auditMeta(r))
	if err != nil {
		cleanup()
		switch {
		case errors.Is(err, store.ErrNotFound):
			writeProblem(w, r, http.StatusNotFound, "MERGE_NOT_FOUND", "merge request or selected item not found")
		case errors.Is(err, store.ErrConflict):
			writeProblem(w, r, http.StatusConflict, "MERGE_ALREADY_REVIEWED", "merge request is no longer pending")
		case errors.Is(err, store.ErrInvalidRequest):
			writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_MERGE", "merge selection is not valid")
		default:
			a.writeAccessError(w, r, err)
		}
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (a *API) rejectFamilyMerge(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if principal.Membership.Role != "owner" {
		writeProblem(w, r, http.StatusForbidden, "OWNER_REQUIRED", "only the family owner can reject a merge")
		return
	}
	var payload mergeReviewPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	result, err := a.Store.ReviewMergeRequest(r.Context(), store.MergeReviewInput{
		RequestID:      strings.TrimSpace(chi.URLParam(r, "requestID")),
		TargetFamilyID: principal.Family.ID,
		ReviewerUserID: principal.User.ID,
		Approve:        false,
		Note:           payload.Note,
	}, auditMeta(r))
	if err != nil {
		switch {
		case errors.Is(err, store.ErrNotFound):
			writeProblem(w, r, http.StatusNotFound, "MERGE_NOT_FOUND", "merge request not found")
		case errors.Is(err, store.ErrConflict):
			writeProblem(w, r, http.StatusConflict, "MERGE_ALREADY_REVIEWED", "merge request is no longer pending")
		default:
			a.writeAccessError(w, r, err)
		}
		return
	}
	writeJSON(w, http.StatusOK, result)
}
