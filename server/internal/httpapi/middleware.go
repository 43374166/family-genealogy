package httpapi

import (
	"log/slog"
	"net/http"
	"runtime/debug"
	"time"

	chimw "github.com/go-chi/chi/v5/middleware"
)

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}

func requestLogger(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			wrapped := chimw.NewWrapResponseWriter(w, r.ProtoMajor)
			defer func() {
				logger.LogAttrs(r.Context(), slog.LevelInfo, "http request",
					slog.String("method", r.Method),
					slog.String("path", r.URL.Path),
					slog.Int("status", wrapped.Status()),
					slog.Int("bytes", wrapped.BytesWritten()),
					slog.Duration("duration", time.Since(start)),
					slog.String("request_id", chimw.GetReqID(r.Context())),
				)
			}()
			next.ServeHTTP(wrapped, r)
		})
	}
}

func recoverer(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if recovered := recover(); recovered != nil {
					logger.ErrorContext(r.Context(), "panic recovered",
						"panic", recovered,
						"stack", string(debug.Stack()),
					)
					if wrapped, ok := w.(chimw.WrapResponseWriter); ok && wrapped.Status() != 0 {
						return
					}
					writeProblem(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}
