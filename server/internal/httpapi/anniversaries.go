package httpapi

import (
	"net/http"
	"strconv"
	"time"
)

func shanghaiNow() time.Time {
	location, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		location = time.FixedZone("CST", 8*60*60)
	}
	return time.Now().In(location)
}

func (a *API) listAnniversaries(w http.ResponseWriter, r *http.Request) {
	principal, ok := principalFrom(r.Context())
	if !ok {
		writeProblem(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
		return
	}
	days := 60
	if raw := r.URL.Query().Get("days"); raw != "" {
		if value, err := strconv.Atoi(raw); err == nil && value >= 1 && value <= 366 {
			days = value
		}
	}
	items, err := a.Store.UpcomingAnniversaries(
		r.Context(), principal.Family.ID, days, shanghaiNow(),
	)
	if err != nil {
		a.writeAccessError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "days": days})
}
