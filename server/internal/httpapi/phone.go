package httpapi

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/43374166/family-genealogy/server/internal/auth"
	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/43374166/family-genealogy/server/internal/sms"
	"github.com/43374166/family-genealogy/server/internal/store"
)

type phonePayload struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

func (a *API) sendLoginCode(w http.ResponseWriter, r *http.Request) {
	var payload phonePayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Phone = strings.TrimSpace(payload.Phone)
	if !validPhone(payload.Phone) {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_PHONE", "phone must use E.164 format")
		return
	}
	if _, err := a.Store.UserIDByPhone(r.Context(), payload.Phone); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeProblem(w, r, http.StatusNotFound, "PHONE_NOT_REGISTERED", "this phone is not registered; register with an invite first")
			return
		}
		logError(a.Logger, r, "phone lookup failed", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
		return
	}
	if err := a.issuePhoneCode(r, payload.Phone, "", "login"); err != nil {
		a.writePhoneError(w, r, err)
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]any{
		"retryAfterSeconds": 60,
		"expiresInSeconds":  300,
	})
}

func (a *API) sendBindCode(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload phonePayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Phone = strings.TrimSpace(payload.Phone)
	if !validPhone(payload.Phone) {
		writeProblem(w, r, http.StatusUnprocessableEntity, "INVALID_PHONE", "phone must use E.164 format")
		return
	}
	inUse, err := a.Store.PhoneInUse(r.Context(), payload.Phone, principal.User.ID)
	if err != nil {
		a.writePhoneError(w, r, err)
		return
	}
	if inUse {
		writeProblem(w, r, http.StatusConflict, "PHONE_TAKEN", "phone is already bound to another account")
		return
	}
	if err := a.issuePhoneCode(r, payload.Phone, principal.User.ID, "bind"); err != nil {
		a.writePhoneError(w, r, err)
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]any{
		"retryAfterSeconds": 60,
		"expiresInSeconds":  300,
	})
}

func (a *API) issuePhoneCode(r *http.Request, phone, userID, purpose string) error {
	code, err := randomDigits()
	if err != nil {
		return err
	}
	hash := store.HashOTP(phone, purpose, code, a.OTP.Pepper)
	if err := a.Store.CreatePhoneCode(
		r.Context(), phone, userID, purpose, hash,
		clientIP(r), a.OTP,
	); err != nil {
		return err
	}
	if err := a.SMS.SendCode(phone, code); err != nil {
		_ = a.Store.DeletePhoneCode(r.Context(), phone, purpose)
		return fmt.Errorf("%w: %v", sms.ErrUnavailable, err)
	}
	return nil
}

func (a *API) loginWithPhone(w http.ResponseWriter, r *http.Request) {
	var payload phonePayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Phone = strings.TrimSpace(payload.Phone)
	payload.Code = strings.TrimSpace(payload.Code)
	if !validPhone(payload.Phone) || len(payload.Code) != 6 {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CODE", "phone or verification code is invalid")
		return
	}
	hash := store.HashOTP(payload.Phone, "login", payload.Code, a.OTP.Pepper)
	if err := a.Store.VerifyPhoneCode(
		r.Context(), payload.Phone, "", "login", hash,
	); err != nil {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CODE", "verification code is invalid or expired")
		return
	}
	userID, err := a.Store.UserIDByPhone(r.Context(), payload.Phone)
	if err != nil {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CODE", "phone is not registered")
		return
	}
	user, err := a.Store.GetActiveUser(r.Context(), userID)
	if err != nil {
		writeProblem(w, r, http.StatusUnauthorized, "ACCOUNT_DISABLED", "account is not active")
		return
	}
	membership, family, err := a.Store.GetPrimaryMembership(r.Context(), user.ID)
	if err != nil {
		if errors.Is(err, store.ErrNoMembership) {
			writeProblem(w, r, http.StatusForbidden, "NO_FAMILY", "account has no active family")
			return
		}
		a.writePhoneError(w, r, err)
		return
	}
	_ = membership
	session, err := a.createSession(r, user, family)
	if err != nil {
		a.writePhoneError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, session)
}

func (a *API) bindPhone(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	var payload phonePayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	payload.Phone = strings.TrimSpace(payload.Phone)
	payload.Code = strings.TrimSpace(payload.Code)
	if !validPhone(payload.Phone) || len(payload.Code) != 6 {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CODE", "phone or verification code is invalid")
		return
	}
	hash := store.HashOTP(payload.Phone, "bind", payload.Code, a.OTP.Pepper)
	if err := a.Store.VerifyPhoneCode(
		r.Context(), payload.Phone, principal.User.ID, "bind", hash,
	); err != nil {
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CODE", "verification code is invalid or expired")
		return
	}
	if err := a.Store.BindPhone(
		r.Context(), principal.Family.ID, principal.User.ID,
		payload.Phone, auditMeta(r),
	); err != nil {
		a.writePhoneError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"phone": payload.Phone})
}

func (a *API) createSession(
	r *http.Request,
	user *model.User,
	family *model.Family,
) (model.Session, error) {
	token, digest, err := auth.NewSessionToken()
	if err != nil {
		return model.Session{}, fmt.Errorf("generate session: %w", err)
	}
	expiresAt := time.Now().UTC().Add(sessionLifetime)
	if _, err := a.Store.CreateSession(
		r.Context(), user.ID, digest, expiresAt,
		clientIP(r), truncate(r.UserAgent(), 512),
	); err != nil {
		return model.Session{}, fmt.Errorf("create session: %w", err)
	}
	if err := a.Store.UpdateLastLogin(r.Context(), user.ID); err != nil {
		a.Logger.WarnContext(r.Context(), "last login update failed", "error", err)
	}
	return model.Session{
		Token: token, ExpiresAt: expiresAt,
		User: *user, Family: *family,
	}, nil
}

func (a *API) writePhoneError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, store.ErrCodeRateLimited):
		w.Header().Set("Retry-After", "60")
		writeProblem(w, r, http.StatusTooManyRequests, "CODE_RATE_LIMITED", "please wait before requesting another code")
	case errors.Is(err, store.ErrInvalidCode):
		writeProblem(w, r, http.StatusUnauthorized, "INVALID_CODE", "verification code is invalid or expired")
	case errors.Is(err, store.ErrConflict):
		writeProblem(w, r, http.StatusConflict, "PHONE_TAKEN", "phone is already bound to another account")
	case errors.Is(err, sms.ErrUnavailable):
		writeProblem(w, r, http.StatusServiceUnavailable, "SMS_UNAVAILABLE", "SMS service is not configured")
	case errors.Is(err, store.ErrNotFound):
		writeProblem(w, r, http.StatusNotFound, "NOT_FOUND", "resource not found")
	default:
		logError(a.Logger, r, "phone operation failed", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
	}
}

func validPhone(phone string) bool {
	if len(phone) < 9 || len(phone) > 16 || phone[0] != '+' {
		return false
	}
	for index, character := range phone[1:] {
		if character < '0' || character > '9' {
			return false
		}
		if index == 0 && character == '0' {
			return false
		}
	}
	return true
}

func randomDigits() (string, error) {
	max := big.NewInt(1000000)
	value, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", fmt.Errorf("generate verification code: %w", err)
	}
	return fmt.Sprintf("%06d", value.Int64()), nil
}
