package httpapi

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/43374166/family-genealogy/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

const maxPhotoBytes = 8 << 20

func (a *API) listPhotos(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	items, err := a.Store.ListPhotos(r.Context(), principal.Family.ID, store.PhotoFilter{
		PersonID: strings.TrimSpace(r.URL.Query().Get("personId")),
		Limit:    100,
	})
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	result := make([]map[string]any, 0, len(items))
	for _, item := range items {
		result = append(result, photoResponse(item))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": result})
}

func photoResponse(item model.Photo) map[string]any {
	return map[string]any{
		"id": item.ID, "familyId": item.FamilyID,
		"personId": item.PersonID, "personName": item.PersonName,
		"uploadedByUserId": item.UploadedByUserID,
		"uploadedByName":   item.UploadedByName,
		"contentType":      item.ContentType, "sizeBytes": item.SizeBytes,
		"caption": item.Caption, "takenAt": item.TakenAt,
		"createdAt":   item.CreatedAt,
		"contentPath": "/api/v1/photos/" + item.ID + "/content",
	}
}

func (a *API) uploadPhoto(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if a.Photos == nil {
		writeProblem(w, r, http.StatusServiceUnavailable, "PHOTOS_UNAVAILABLE", "photo storage is not configured")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxPhotoBytes+(2<<20))
	if err := r.ParseMultipartForm(maxPhotoBytes + (2 << 20)); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_UPLOAD", "invalid multipart upload")
		return
	}
	file, _, err := r.FormFile("file")
	if err != nil {
		writeProblem(w, r, http.StatusBadRequest, "FILE_REQUIRED", "file is required")
		return
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, maxPhotoBytes+1))
	if err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_FILE", "could not read file")
		return
	}
	if len(data) == 0 || len(data) > maxPhotoBytes {
		writeProblem(w, r, http.StatusRequestEntityTooLarge, "FILE_TOO_LARGE", "photo must be at most 8 MB")
		return
	}
	contentType := http.DetectContentType(data)
	extension := ""
	switch contentType {
	case "image/jpeg":
		extension = ".jpg"
	case "image/png":
		extension = ".png"
	case "image/webp":
		extension = ".webp"
	default:
		writeProblem(w, r, http.StatusUnsupportedMediaType, "UNSUPPORTED_IMAGE", "only JPEG, PNG or WebP images are supported")
		return
	}
	personID := strings.TrimSpace(r.FormValue("personId"))
	caption := strings.TrimSpace(r.FormValue("caption"))
	if len([]rune(caption)) > 500 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "CAPTION_TOO_LONG", "caption is too long")
		return
	}
	takenAt, err := parsePhotoDate(r.FormValue("takenAt"))
	if err != nil {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_TAKEN_AT", "takenAt must be YYYY-MM-DD")
		return
	}
	objectKey := a.Photos.ObjectKey(
		principal.Family.ID, uuid.NewString()+extension,
	)
	if err := a.Photos.Put(r.Context(), objectKey, data, contentType); err != nil {
		logError(a.Logger, r, "photo upload failed", err)
		writeProblem(w, r, http.StatusBadGateway, "PHOTO_UPLOAD_FAILED", "could not store photo")
		return
	}
	photo, err := a.Store.CreatePhoto(
		r.Context(), principal.Family.ID, principal.User.ID, personID,
		objectKey, contentType, int64(len(data)), caption, takenAt,
	)
	if err != nil {
		_ = a.Photos.Delete(r.Context(), objectKey)
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, photoResponse(*photo))
}

func (a *API) photoContent(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if a.Photos == nil {
		writeProblem(w, r, http.StatusServiceUnavailable, "PHOTOS_UNAVAILABLE", "photo storage is not configured")
		return
	}
	photoID := strings.TrimSpace(chi.URLParam(r, "photoID"))
	photo, err := a.Store.GetPhoto(r.Context(), principal.Family.ID, photoID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	objectKey, err := a.Store.PhotoObjectKey(r.Context(), principal.Family.ID, photoID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	body, contentType, _, err := a.Photos.Get(r.Context(), objectKey)
	if err != nil {
		logError(a.Logger, r, "photo content failed", err)
		writeProblem(w, r, http.StatusBadGateway, "PHOTO_READ_FAILED", "could not read photo")
		return
	}
	defer body.Close()
	if contentType == "" {
		contentType = photo.ContentType
	}
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "private, max-age=3600")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	_, _ = io.Copy(w, body)
}

type updatePhotoPayload struct {
	PersonID string `json:"personId"`
	Caption  string `json:"caption"`
	TakenAt  string `json:"takenAt"`
}

func (a *API) updatePhoto(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload updatePhotoPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.PersonID = strings.TrimSpace(payload.PersonID)
	payload.Caption = strings.TrimSpace(payload.Caption)
	if len([]rune(payload.Caption)) > 500 {
		writeProblem(w, r, http.StatusUnprocessableEntity, "CAPTION_TOO_LONG", "caption is too long")
		return
	}
	takenAt, err := parsePhotoDate(payload.TakenAt)
	if err != nil {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_TAKEN_AT", "takenAt must be YYYY-MM-DD")
		return
	}
	photo, err := a.Store.UpdatePhotoMetadata(
		r.Context(), principal.Family.ID, chi.URLParam(r, "photoID"),
		principal.User.ID, payload.PersonID, payload.Caption, takenAt,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, photoResponse(*photo))
}

func parsePhotoDate(value string) (*time.Time, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil, nil
	}
	for _, layout := range []string{"2006-01-02", time.RFC3339} {
		parsed, err := time.Parse(layout, value)
		if err == nil {
			utc := parsed.UTC()
			return &utc, nil
		}
	}
	return nil, fmt.Errorf("invalid photo date %q", value)
}

func (a *API) deletePhoto(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if a.Photos == nil {
		writeProblem(w, r, http.StatusServiceUnavailable, "PHOTOS_UNAVAILABLE", "photo storage is not configured")
		return
	}
	photoID := strings.TrimSpace(chi.URLParam(r, "photoID"))
	objectKey, err := a.Store.DeletePhoto(
		r.Context(), principal.Family.ID, photoID, principal.User.ID,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	if err := a.Photos.Delete(r.Context(), objectKey); err != nil {
		a.Logger.WarnContext(r.Context(), "photo object delete failed", "error", err)
	}
	w.WriteHeader(http.StatusNoContent)
}
