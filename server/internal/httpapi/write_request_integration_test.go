package httpapi_test

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/43374166/family-genealogy/server/internal/database"
	"github.com/43374166/family-genealogy/server/internal/httpapi"
	"github.com/43374166/family-genealogy/server/internal/store"
)

func TestWriteRequestWorkflow(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_DSN")
	if dsn == "" {
		t.Skip("TEST_DATABASE_DSN is not set; skip HTTP/MySQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	db, err := database.Open(ctx, dsn, 2)
	if err != nil {
		t.Fatalf("open test database: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	server := httptest.NewServer(httpapi.NewRouter(httpapi.Dependencies{
		DB:     db,
		Store:  store.New(db.DB),
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	}))
	t.Cleanup(server.Close)

	var login struct {
		Token string `json:"token"`
	}
	response := doJSON(t, http.DefaultClient, http.MethodPost, server.URL+"/api/v1/auth/login",
		`{"loginName":"linglei","password":"Demo#2026"}`, "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("login status = %d", response.StatusCode)
	}
	decodeBody(t, response, &login)

	suffix := time.Now().UnixNano()
	personPayload := map[string]any{
		"surname":      "凌",
		"givenName":    fmt.Sprintf("申请%d", suffix),
		"gender":       "male",
		"generationNo": 3,
		"branchId":     "40000000-0000-4000-8000-000000000002",
		"birthOrder":   8,
	}
	createBody, _ := json.Marshal(map[string]any{
		"requestType": "create_person",
		"payload":     personPayload,
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/edit-requests/write", string(createBody), login.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create write request status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var request struct {
		ID      string `json:"id"`
		Status  string `json:"status"`
		Summary string `json:"summary"`
	}
	decodeBody(t, response, &request)
	if request.Status != "pending" || request.Summary == "" {
		t.Fatalf("unexpected request: %+v", request)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/edit-requests/"+request.ID+"/approve",
		`{"note":"准许入谱"}`, login.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("approve write request status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var approved struct {
		Status string `json:"status"`
	}
	decodeBody(t, response, &approved)
	if approved.Status != "approved" {
		t.Fatalf("status = %q", approved.Status)
	}

	var personID string
	if err := db.DB.QueryRowContext(ctx, `
		SELECT id FROM persons
		WHERE family_id = '10000000-0000-4000-8000-000000000001'
		  AND given_name = ?`, personPayload["givenName"],
	).Scan(&personID); err != nil {
		t.Fatalf("find created person: %v", err)
	}
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM parent_child_relationships WHERE parent_id = ? OR child_id = ?`, personID, personID)
		_, _ = db.DB.Exec(`DELETE FROM spouse_relationships WHERE person_a_id = ? OR person_b_id = ?`, personID, personID)
		_, _ = db.DB.Exec(`DELETE FROM persons WHERE id = ?`, personID)
	})
	if personID == "" {
		t.Fatal("approved request did not create a person")
	}
}
