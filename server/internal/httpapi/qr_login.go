package httpapi

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/43374166/family-genealogy/server/internal/auth"
	"github.com/43374166/family-genealogy/server/internal/geoip"
	"github.com/43374166/family-genealogy/server/internal/model"
	"github.com/43374166/family-genealogy/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

const qrLoginTTL = 2 * time.Minute

type qrSecretPayload struct {
	Secret string `json:"secret"`
}

type qrStatus struct {
	ID            string         `json:"id"`
	Status        string         `json:"status"`
	ExpiresAt     time.Time      `json:"expiresAt"`
	ScannedAt     *time.Time     `json:"scannedAt,omitempty"`
	ConfirmedAt   *time.Time     `json:"confirmedAt,omitempty"`
	RequestIP     string         `json:"requestIp,omitempty"`
	RequestCity   string         `json:"requestCity,omitempty"`
	RequestRegion string         `json:"requestRegion,omitempty"`
	RequestDevice string         `json:"requestDevice,omitempty"`
	Session       *model.Session `json:"session,omitempty"`
}

type qrCreateResponse struct {
	qrStatus
	Secret         string `json:"secret"`
	Payload        string `json:"payload"`
	PollIntervalMS int    `json:"pollIntervalMs"`
}

func (a *API) createQRLogin(w http.ResponseWriter, r *http.Request) {
	if a.Store == nil {
		writeProblem(w, r, http.StatusServiceUnavailable, "QR_UNAVAILABLE", "qr login is unavailable")
		return
	}
	secret, secretHash, err := auth.NewSessionToken()
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	id := uuid.NewString()
	ip := clientIP(r)
	userAgent := truncate(strings.TrimSpace(r.UserAgent()), 512)
	location := a.locationForQR(ip)
	expiresAt := time.Now().UTC().Add(qrLoginTTL)
	if err := a.Store.CreateQRLoginSession(r.Context(), store.QRLoginCreateInput{
		ID:                 id,
		SecretHash:         secretHash,
		RequesterIP:        ip,
		RequesterCity:      location.City,
		RequesterRegion:    location.Region,
		RequesterCountry:   location.Country,
		RequesterUserAgent: userAgent,
		RequesterDevice:    describeUserAgent(userAgent),
		ExpiresAt:          expiresAt,
	}); err != nil {
		if errors.Is(err, store.ErrQRLimit) {
			writeProblem(w, r, http.StatusTooManyRequests, "QR_RATE_LIMITED", "too many qr login attempts")
			return
		}
		a.writeAccessError(w, r, err)
		return
	}
	payload := webLoginPayload(id, secret)
	writeNoStore(w)
	writeJSON(w, http.StatusCreated, qrCreateResponse{
		qrStatus: qrStatus{
			ID:            id,
			Status:        model.QRStatusPending,
			ExpiresAt:     expiresAt,
			RequestIP:     ip,
			RequestCity:   location.City,
			RequestRegion: location.Region,
			RequestDevice: describeUserAgent(userAgent),
		},
		Secret:         secret,
		Payload:        payload,
		PollIntervalMS: 2000,
	})
}

// locationForQR resolves the IP's approximate city before returning the QR.
// The lookup is capped by the geoip client (3s); if the provider is slow or
// unavailable, the QR is still created and clients show an unknown location.
// This is intentionally synchronous so the scanned confirmation always shows
// the same location data that was recorded for the browser request.
func (a *API) locationForQR(ip string) geoip.Location {
	if a.Geo == nil {
		return geoip.Location{IP: ip}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3500*time.Millisecond)
	defer cancel()
	return a.Geo.Lookup(ctx, ip)
}

func (a *API) getQRLogin(w http.ResponseWriter, r *http.Request) {
	if a.Store == nil {
		writeProblem(w, r, http.StatusServiceUnavailable, "QR_UNAVAILABLE", "qr login is unavailable")
		return
	}
	secret := strings.TrimSpace(r.URL.Query().Get("secret"))
	if !validQRSecret(secret) {
		writeProblem(w, r, http.StatusNotFound, "QR_NOT_FOUND", "qr login not found")
		return
	}
	qr, err := a.Store.GetQRLoginSession(r.Context(), strings.TrimSpace(chi.URLParam(r, "qrID")), auth.HashSessionToken(secret))
	if err != nil {
		a.writeQRError(w, r, err)
		return
	}
	status := toQRStatus(*qr)
	switch qr.Status {
	case model.QRStatusConfirmed:
		// The QR secret is the browser's proof of possession. Consume the
		// confirmed row before issuing so a replay cannot get a second token.
		consumed, err := a.Store.ConsumeQRLogin(r.Context(), qr.ID, auth.HashSessionToken(secret))
		if err != nil {
			a.writeQRError(w, r, err)
			return
		}
		session, err := a.createSessionForQR(r.Context(), consumed)
		if err != nil {
			a.writeQRError(w, r, err)
			return
		}
		status = toQRStatus(*consumed)
		// The externally visible state is "confirmed" on the poll that issues
		// the session; "consumed" is the replay-protection state used by the
		// next poll (which returns 409).
		status.Status = model.QRStatusConfirmed
		status.Session = session
	case model.QRStatusConsumed:
		writeProblem(w, r, http.StatusConflict, "QR_ALREADY_USED", "qr login already used")
		return
	}
	writeNoStore(w)
	writeJSON(w, http.StatusOK, status)
}

func (a *API) createSessionForQR(
	ctx context.Context, qr *model.QRLoginSession,
) (*model.Session, error) {
	if qr.UserID == nil || qr.FamilyID == nil {
		return nil, store.ErrQRState
	}
	user, err := a.Store.GetActiveUser(ctx, *qr.UserID)
	if err != nil {
		return nil, err
	}
	_, family, err := a.Store.GetMembership(ctx, *qr.UserID, *qr.FamilyID)
	if err != nil {
		return nil, err
	}
	token, digest, err := auth.NewSessionToken()
	if err != nil {
		return nil, err
	}
	expiresAt := time.Now().UTC().Add(sessionLifetime)
	if _, err := a.Store.CreateSession(
		ctx, user.ID, digest, expiresAt, family.ID,
		qr.RequesterIP, qr.RequesterUserAgent,
	); err != nil {
		return nil, err
	}
	return &model.Session{
		Token:     token,
		ExpiresAt: expiresAt,
		User:      *user,
		Family:    *family,
	}, nil
}

func (a *API) scanQRLogin(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	secret, ok := decodeQRSecret(w, r)
	if !ok {
		return
	}
	qr, err := a.Store.MarkQRLoginScanned(
		r.Context(), strings.TrimSpace(chi.URLParam(r, "qrID")),
		auth.HashSessionToken(secret), principal.User.ID,
	)
	if err != nil {
		a.writeQRError(w, r, err)
		return
	}
	writeNoStore(w)
	writeJSON(w, http.StatusOK, toQRStatus(*qr))
}

func (a *API) confirmQRLogin(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	secret, ok := decodeQRSecret(w, r)
	if !ok {
		return
	}
	qr, err := a.Store.ConfirmQRLogin(
		r.Context(), strings.TrimSpace(chi.URLParam(r, "qrID")),
		auth.HashSessionToken(secret), principal.User.ID, principal.Family.ID,
	)
	if err != nil {
		a.writeQRError(w, r, err)
		return
	}
	writeNoStore(w)
	writeJSON(w, http.StatusOK, toQRStatus(*qr))
}

func (a *API) cancelQRLogin(w http.ResponseWriter, r *http.Request) {
	secret, ok := decodeQRSecret(w, r)
	if !ok {
		return
	}
	if err := a.Store.CancelQRLogin(
		r.Context(), strings.TrimSpace(chi.URLParam(r, "qrID")),
		auth.HashSessionToken(secret),
	); err != nil {
		a.writeQRError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func decodeQRSecret(w http.ResponseWriter, r *http.Request) (string, bool) {
	var payload qrSecretPayload
	if err := decodeJSON(w, r, &payload); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return "", false
	}
	payload.Secret = strings.TrimSpace(payload.Secret)
	if !validQRSecret(payload.Secret) {
		writeProblem(w, r, http.StatusUnprocessableEntity, "QR_SECRET_REQUIRED", "a valid qr secret is required")
		return "", false
	}
	return payload.Secret, true
}

func validQRSecret(secret string) bool {
	return len(secret) >= 20 && len(secret) <= 256
}

func toQRStatus(qr model.QRLoginSession) qrStatus {
	return qrStatus{
		ID:            qr.ID,
		Status:        qr.Status,
		ExpiresAt:     qr.ExpiresAt,
		ScannedAt:     qr.ScannedAt,
		ConfirmedAt:   qr.ConfirmedAt,
		RequestIP:     qr.RequesterIP,
		RequestCity:   qr.RequesterCity,
		RequestRegion: qr.RequesterRegion,
		RequestDevice: qr.RequesterDevice,
	}
}

func (a *API) writeQRError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		writeProblem(w, r, http.StatusNotFound, "QR_NOT_FOUND", "qr login not found")
	case errors.Is(err, store.ErrQRExpired):
		writeProblem(w, r, http.StatusGone, "QR_EXPIRED", "qr login expired")
	case errors.Is(err, store.ErrQRState):
		writeProblem(w, r, http.StatusConflict, "QR_NOT_AVAILABLE", "qr login is no longer available")
	case errors.Is(err, store.ErrQRLimit):
		writeProblem(w, r, http.StatusTooManyRequests, "QR_RATE_LIMITED", "too many qr login attempts")
	default:
		logError(a.Logger, r, "qr login failed", err)
		writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
	}
}

func writeNoStore(w http.ResponseWriter) {
	w.Header().Set("Cache-Control", "no-store, max-age=0")
	w.Header().Set("Pragma", "no-cache")
}

func webLoginPayload(id, secret string) string {
	values := url.Values{}
	values.Set("v", "1")
	values.Set("id", id)
	values.Set("secret", secret)
	return (&url.URL{Scheme: "familytree", Host: "web-login", RawQuery: values.Encode()}).String()
}

// describeUserAgent produces a short, non-sensitive label for the confirmation
// screen. The raw UA stays server-side for audit only.
func describeUserAgent(raw string) string {
	userAgent := strings.ToLower(raw)
	browser := ""
	switch {
	case strings.Contains(userAgent, "micromessenger"):
		browser = "微信"
	case strings.Contains(userAgent, "edg/"):
		browser = "Edge"
	case strings.Contains(userAgent, "opr/"), strings.Contains(userAgent, "opera"):
		browser = "Opera"
	case strings.Contains(userAgent, "firefox/"):
		browser = "Firefox"
	case strings.Contains(userAgent, "chrome/"), strings.Contains(userAgent, "crios/"):
		browser = "Chrome"
	case strings.Contains(userAgent, "safari/"), strings.Contains(userAgent, "mobile/"):
		browser = "Safari"
	case strings.Contains(userAgent, "curl/"):
		browser = "命令行"
	}
	osName := ""
	switch {
	case strings.Contains(userAgent, "windows"):
		osName = "Windows"
	case strings.Contains(userAgent, "iphone"), strings.Contains(userAgent, "ipad"):
		osName = "iOS"
	case strings.Contains(userAgent, "android"):
		osName = "Android"
	case strings.Contains(userAgent, "macintosh"), strings.Contains(userAgent, "mac os x"):
		osName = "macOS"
	case strings.Contains(userAgent, "linux"):
		osName = "Linux"
	}
	switch {
	case browser != "" && osName != "":
		return browser + " · " + osName
	case browser != "":
		return browser
	case osName != "":
		return osName
	default:
		return "未知设备"
	}
}
