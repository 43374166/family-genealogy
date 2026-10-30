package httpapi

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakePinger struct {
	err error
}

func (f fakePinger) Ping(context.Context) error { return f.err }

func testRouter(db Pinger) http.Handler {
	return NewRouter(Dependencies{
		DB:     db,
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
}

func TestLiveness(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	testRouter(fakePinger{}).ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), `"status":"ok"`) {
		t.Fatalf("unexpected body: %s", rec.Body.String())
	}
}

func TestReadinessReportsDatabaseFailure(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	rec := httptest.NewRecorder()

	testRouter(fakePinger{err: errors.New("database unavailable")}).ServeHTTP(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503", rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); !strings.HasPrefix(got, "application/problem+json") {
		t.Fatalf("Content-Type = %q", got)
	}
	if !strings.Contains(rec.Body.String(), `"code":"DEPENDENCY_UNAVAILABLE"`) {
		t.Fatalf("unexpected body: %s", rec.Body.String())
	}
}

func TestMetaReturnsBuildInfo(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/v1/meta", nil)
	rec := httptest.NewRecorder()

	testRouter(fakePinger{}).ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), `"service":"family-tree-api"`) {
		t.Fatalf("unexpected body: %s", rec.Body.String())
	}
}

func TestUnknownRouteUsesProblemDetails(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/v1/does-not-exist", nil)
	rec := httptest.NewRecorder()

	testRouter(fakePinger{}).ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), `"code":"NOT_FOUND"`) {
		t.Fatalf("unexpected body: %s", rec.Body.String())
	}
}
