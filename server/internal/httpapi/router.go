package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/43374166/family-genealogy/server/internal/buildinfo"
	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
)

type Dependencies struct {
	DB     Pinger
	Logger *slog.Logger
}

func NewRouter(deps Dependencies) http.Handler {
	logger := deps.Logger
	if logger == nil {
		logger = slog.Default()
	}

	router := chi.NewRouter()
	router.Use(chimw.RequestID)
	router.Use(requestLogger(logger))
	router.Use(recoverer(logger))
	router.Use(securityHeaders)

	health := healthHandler{db: deps.DB, logger: logger}
	router.Get("/healthz", health.live)
	router.Get("/readyz", health.ready)

	router.Route("/api/v1", func(r chi.Router) {
		r.Get("/meta", func(w http.ResponseWriter, _ *http.Request) {
			writeJSON(w, http.StatusOK, buildinfo.Current())
		})
	})

	router.NotFound(func(w http.ResponseWriter, r *http.Request) {
		writeProblem(w, r, http.StatusNotFound, "NOT_FOUND", "resource not found")
	})
	router.MethodNotAllowed(func(w http.ResponseWriter, r *http.Request) {
		writeProblem(w, r, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "method not allowed")
	})

	return router
}
