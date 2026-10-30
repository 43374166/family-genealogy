package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/43374166/family-genealogy/server/internal/buildinfo"
	"github.com/43374166/family-genealogy/server/internal/store"
	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
)

type Dependencies struct {
	DB     Pinger
	Store  *store.Store
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

	api := &API{Store: deps.Store, Logger: logger}
	router.Route("/api/v1", func(r chi.Router) {
		r.Get("/meta", func(w http.ResponseWriter, _ *http.Request) {
			writeJSON(w, http.StatusOK, buildinfo.Current())
		})

		if deps.Store == nil {
			return
		}

		r.Post("/auth/login", api.login)
		r.Post("/auth/register", api.register)
		r.Group(func(r chi.Router) {
			r.Use(api.authenticate)
			r.Post("/auth/logout", api.logout)
			r.Get("/invites", api.listInvites)
			r.Post("/invites", api.createInvite)
			r.Get("/accounts", api.listFamilyAccounts)
			r.Get("/branch-admins", api.listBranchAdmins)
			r.Post("/branch-admins", api.grantBranchAdmin)
			r.Delete("/branch-admins/{grantID}", api.revokeBranchAdmin)
			r.Post("/bind-requests", api.createBindingRequest)
			r.Get("/bind-requests", api.listBindingRequests)
			r.Post("/bind-requests/{requestID}/approve", api.approveBindingRequest)
			r.Post("/bind-requests/{requestID}/reject", api.rejectBindingRequest)
			r.Get("/me", api.me)
			r.Get("/family", api.getFamily)
			r.Get("/tree", api.getTree)
			r.Get("/branches", api.listBranches)
			r.Get("/persons", api.listPersons)
			r.Post("/persons", api.createPerson)
			r.Get("/persons/{personID}", api.getPerson)
			r.Post("/relationships/parent-child", api.addParentChild)
			r.Post("/relationships/spouse", api.addSpouse)
			r.Post("/edit-requests", api.createEditRequest)
			r.Post("/edit-requests/write", api.createWriteRequest)
			r.Get("/edit-requests", api.listEditRequests)
			r.Get("/edit-requests/{requestID}", api.getEditRequest)
			r.Post("/edit-requests/{requestID}/approve", api.approveEditRequest)
			r.Post("/edit-requests/{requestID}/reject", api.rejectEditRequest)
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
