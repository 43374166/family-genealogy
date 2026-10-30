package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/43374166/family-genealogy/server/internal/auth"
	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/43374166/family-genealogy/server/internal/obsstore"
	smssvc "github.com/43374166/family-genealogy/server/internal/sms"
	"github.com/43374166/family-genealogy/server/internal/store"
)

const sessionLifetime = 30 * 24 * time.Hour

type API struct {
	Store  *store.Store
	Logger *slog.Logger
	SMS    smssvc.Sender
	OTP    store.OTPPolicy
	Photos *obsstore.Store
}

type principalKey struct{}

func principalFrom(ctx context.Context) (*store.Principal, bool) {
	principal, ok := ctx.Value(principalKey{}).(*store.Principal)
	return principal, ok
}

func (a *API) authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		parts := strings.Fields(r.Header.Get("Authorization"))
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || parts[1] == "" {
			writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing or invalid bearer token")
			return
		}
		if len(parts[1]) < 20 || len(parts[1]) > 256 {
			writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "invalid session")
			return
		}

		principal, err := a.Store.GetPrincipal(r.Context(), auth.HashSessionToken(parts[1]))
		if err != nil {
			if !errors.Is(err, store.ErrUnauthorized) {
				a.Logger.ErrorContext(r.Context(), "session lookup failed", "error", err)
			}
			writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "session is invalid or expired")
			return
		}
		_ = a.Store.TouchSession(r.Context(), principal.SessionID)
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), principalKey{}, principal)))
	})
}

type loginRequest struct {
	LoginName string `json:"loginName"`
	Password  string `json:"password"`
}

func (a *API) login(w http.ResponseWriter, r *http.Request) {
	var request loginRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	request.LoginName = strings.TrimSpace(request.LoginName)
	if request.LoginName == "" || len(request.LoginName) > 80 || len(request.Password) < 8 || len(request.Password) > 256 {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "invalid login name or password")
		return
	}

	user, passwordHash, err := a.Store.GetLoginUser(r.Context(), request.LoginName)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "invalid login name or password")
			return
		}
		a.Logger.ErrorContext(r.Context(), "login user lookup failed", "error", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	if user.Status != "active" {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "invalid login name or password")
		return
	}
	if lockedUntil, err := a.Store.LoginLockedUntil(r.Context(), request.LoginName); err == nil && !lockedUntil.IsZero() {
		seconds := int(time.Until(lockedUntil).Seconds())
		if seconds < 1 {
			seconds = 60
		}
		w.Header().Set("Retry-After", fmt.Sprintf("%d", seconds))
		writeProblem(w, r, http.StatusTooManyRequests, "LOGIN_LOCKED", "too many failed attempts; try again later")
		return
	}

	ok, err := auth.VerifyPassword(passwordHash, request.Password)
	if err != nil {
		a.Logger.ErrorContext(r.Context(), "stored password hash is invalid", "error", err, "user_id", user.ID)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	if !ok {
		_ = a.Store.RecordFailedLogin(r.Context(), user.ID)
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "invalid login name or password")
		return
	}
	_ = a.Store.ResetFailedLogin(r.Context(), user.ID)

	_, family, err := a.Store.GetPreferredMembership(r.Context(), user.ID)
	if err != nil {
		if errors.Is(err, store.ErrNoMembership) {
			writeProblem(w, r, http.StatusForbidden, "NO_FAMILY", "account has no active family")
			return
		}
		a.Logger.ErrorContext(r.Context(), "membership lookup failed", "error", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}

	token, digest, err := auth.NewSessionToken()
	if err != nil {
		a.Logger.ErrorContext(r.Context(), "session token generation failed", "error", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	expiresAt := time.Now().UTC().Add(sessionLifetime)
	if _, err := a.Store.CreateSession(
		r.Context(), user.ID, digest, expiresAt, family.ID,
		clientIP(r), truncate(r.UserAgent(), 512),
	); err != nil {
		a.Logger.ErrorContext(r.Context(), "session creation failed", "error", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	if err := a.Store.UpdateLastLogin(r.Context(), user.ID); err != nil {
		a.Logger.WarnContext(r.Context(), "last login update failed", "error", err)
	}

	writeJSON(w, http.StatusOK, model.Session{
		Token:     token,
		ExpiresAt: expiresAt,
		User:      *user,
		Family:    *family,
	})
}

func (a *API) logout(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	if err := a.Store.RevokeSession(r.Context(), principal.SessionID); err != nil {
		a.Logger.ErrorContext(r.Context(), "session revoke failed", "error", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) me(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	families, err := a.Store.ListUserFamilies(r.Context(), principal.User.ID)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, model.Me{
		User:       principal.User,
		Membership: principal.Membership,
		Family:     principal.Family,
		Families:   families,
	})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, destination any) error {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		return err
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return errors.New("request body must contain exactly one JSON object")
	}
	return nil
}

func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil {
		return truncate(host, 45)
	}
	return truncate(r.RemoteAddr, 45)
}

func truncate(value string, max int) string {
	if len(value) <= max {
		return value
	}
	return value[:max]
}

func logError(logger *slog.Logger, r *http.Request, message string, err error) {
	if logger != nil {
		logger.ErrorContext(r.Context(), message, "error", err)
	}
}
