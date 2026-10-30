package httpapi

import (
	"io"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

const maxAvatarBytes = 5 << 20

func (a *API) uploadPersonAvatar(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if a.Photos == nil {
		writeProblem(w, r, http.StatusServiceUnavailable, "PHOTOS_UNAVAILABLE", "object storage is not configured")
		return
	}
	personID := strings.TrimSpace(chi.URLParam(r, "personID"))
	allowed, err := a.Store.CanEditPersonAvatar(
		r.Context(), principal.Family.ID, personID, principal.User.ID,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	if !allowed {
		writeProblem(w, r, http.StatusForbidden, "FORBIDDEN", "you cannot change this person's avatar")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxAvatarBytes+(1<<20))
	if err := r.ParseMultipartForm(maxAvatarBytes + (1 << 20)); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_UPLOAD", "invalid multipart upload")
		return
	}
	file, _, err := r.FormFile("file")
	if err != nil {
		writeProblem(w, r, http.StatusBadRequest, "FILE_REQUIRED", "file is required")
		return
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, maxAvatarBytes+1))
	if err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_FILE", "could not read file")
		return
	}
	if len(data) == 0 || len(data) > maxAvatarBytes {
		writeProblem(w, r, http.StatusRequestEntityTooLarge, "FILE_TOO_LARGE", "avatar must be at most 5 MB")
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
	objectKey := a.Photos.ObjectKey(
		principal.Family.ID, "avatars/"+personID+"/"+uuid.NewString()+extension,
	)
	if err := a.Photos.Put(r.Context(), objectKey, data, contentType); err != nil {
		logError(a.Logger, r, "avatar upload failed", err)
		writeProblem(w, r, http.StatusBadGateway, "AVATAR_UPLOAD_FAILED", "could not store avatar")
		return
	}
	oldKey, err := a.Store.SetPersonAvatar(
		r.Context(), principal.Family.ID, personID, principal.User.ID,
		objectKey, contentType,
	)
	if err != nil {
		_ = a.Photos.Delete(r.Context(), objectKey)
		a.writeAccessError(w, r, err)
		return
	}
	if oldKey != "" && oldKey != objectKey {
		_ = a.Photos.Delete(r.Context(), oldKey)
	}
	writeJSON(w, http.StatusOK, map[string]any{"hasAvatar": true})
}

func (a *API) deletePersonAvatar(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if a.Photos == nil {
		writeProblem(w, r, http.StatusServiceUnavailable, "PHOTOS_UNAVAILABLE", "object storage is not configured")
		return
	}
	oldKey, err := a.Store.ClearPersonAvatar(
		r.Context(), principal.Family.ID,
		strings.TrimSpace(chi.URLParam(r, "personID")), principal.User.ID,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	if oldKey != "" {
		_ = a.Photos.Delete(r.Context(), oldKey)
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) personAvatar(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if a.Photos == nil {
		writeProblem(w, r, http.StatusServiceUnavailable, "PHOTOS_UNAVAILABLE", "object storage is not configured")
		return
	}
	personID := strings.TrimSpace(chi.URLParam(r, "personID"))
	key, contentType, err := a.Store.PersonAvatarKey(
		r.Context(), principal.Family.ID, personID,
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	body, objectType, _, err := a.Photos.Get(r.Context(), key)
	if err != nil {
		logError(a.Logger, r, "avatar read failed", err)
		writeProblem(w, r, http.StatusBadGateway, "AVATAR_READ_FAILED", "could not read avatar")
		return
	}
	defer body.Close()
	if objectType == "" {
		objectType = contentType
	}
	w.Header().Set("Content-Type", objectType)
	w.Header().Set("Cache-Control", "private, max-age=3600")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	_, _ = io.Copy(w, body)
}
