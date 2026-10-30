package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"time"
)

type Pinger interface {
	Ping(context.Context) error
}

type healthHandler struct {
	db     Pinger
	logger *slog.Logger
}

func (h healthHandler) live(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h healthHandler) ready(w http.ResponseWriter, r *http.Request) {
	if h.db == nil {
		writeProblem(w, r, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "database is not configured")
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := h.db.Ping(ctx); err != nil {
		h.logger.WarnContext(ctx, "readiness check failed", "error", err)
		writeProblem(w, r, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "database is not ready")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "database": "ok"})
}
