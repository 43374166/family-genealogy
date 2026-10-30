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

func TestEditRequestWorkflow(t *testing.T) {
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
		`{"loginName":"zhangsan","password":"Demo#2026"}`, "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("login status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	decodeBody(t, response, &login)

	const personID = "50000000-0000-4000-8000-000000000005"
	readPerson := func() (version int, residence string) {
		response := doJSON(t, http.DefaultClient, http.MethodGet,
			server.URL+"/api/v1/persons/"+personID, "", login.Token)
		if response.StatusCode != http.StatusOK {
			t.Fatalf("get person status = %d", response.StatusCode)
		}
		var person struct {
			Version   int    `json:"version"`
			Residence string `json:"residence"`
		}
		decodeBody(t, response, &person)
		return person.Version, person.Residence
	}

	version, _ := readPerson()
	residence := fmt.Sprintf("杭州市测试区-%d", time.Now().UnixNano())
	body, _ := json.Marshal(map[string]any{
		"targetPersonId": personID,
		"baseVersion":    version,
		"changes":        map[string]string{"residence": residence},
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/edit-requests", string(body), login.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create request status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var created struct {
		ID            string   `json:"id"`
		Status        string   `json:"status"`
		ChangedFields []string `json:"changedFields"`
	}
	decodeBody(t, response, &created)
	if created.ID == "" || created.Status != "pending" || len(created.ChangedFields) != 1 {
		t.Fatalf("unexpected created request: %+v", created)
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/edit-requests?status=pending&mine=true", "", login.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("list requests status = %d", response.StatusCode)
	}
	var list struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	decodeBody(t, response, &list)
	found := false
	for _, item := range list.Items {
		if item.ID == created.ID {
			found = true
		}
	}
	if !found {
		t.Fatalf("created request missing from list: %+v", list.Items)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/edit-requests/"+created.ID+"/approve",
		`{"note":"资料核对无误"}`, login.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("approve status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var approved struct {
		Status string `json:"status"`
	}
	decodeBody(t, response, &approved)
	if approved.Status != "approved" {
		t.Fatalf("approved status = %q", approved.Status)
	}
	newVersion, newResidence := readPerson()
	if newResidence != residence || newVersion != version+1 {
		t.Fatalf("person was not updated: version=%d residence=%q", newVersion, newResidence)
	}

	body, _ = json.Marshal(map[string]any{
		"targetPersonId": personID,
		"baseVersion":    newVersion,
		"changes":        map[string]string{"occupation": "测试职业"},
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/edit-requests", string(body), login.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create reject request status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var rejectedRequest struct {
		ID string `json:"id"`
	}
	decodeBody(t, response, &rejectedRequest)
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/edit-requests/"+rejectedRequest.ID+"/reject",
		`{"note":"信息需要补充来源"}`, login.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("reject status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var rejected struct {
		Status     string `json:"status"`
		ReviewNote string `json:"reviewNote"`
	}
	decodeBody(t, response, &rejected)
	if rejected.Status != "rejected" || rejected.ReviewNote == "" {
		t.Fatalf("unexpected rejected request: %+v", rejected)
	}

	var auditCount int
	if err := db.DB.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM audit_logs
		WHERE edit_request_id IN (?, ?)`, created.ID, rejectedRequest.ID,
	).Scan(&auditCount); err != nil {
		t.Fatalf("count audit logs: %v", err)
	}
	if auditCount != 2 {
		t.Fatalf("audit count = %d, want 2", auditCount)
	}
}
