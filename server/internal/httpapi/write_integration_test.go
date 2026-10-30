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

func TestWriteAPI(t *testing.T) {
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

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/branches", "", login.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("branches status = %d", response.StatusCode)
	}
	var branches struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	decodeBody(t, response, &branches)
	if len(branches.Items) != 6 {
		t.Fatalf("branches = %d, want 6", len(branches.Items))
	}

	suffix := time.Now().UnixNano()
	createPerson := func(given string) string {
		body, _ := json.Marshal(map[string]any{
			"surname":      "凌",
			"givenName":    given,
			"gender":       "male",
			"generationNo": 3,
			"branchId":     "40000000-0000-4000-8000-000000000002",
			"birthOrder":   9,
		})
		response := doJSON(t, http.DefaultClient, http.MethodPost,
			server.URL+"/api/v1/persons", string(body), login.Token)
		if response.StatusCode != http.StatusCreated {
			t.Fatalf("create person status = %d, body = %s", response.StatusCode, readBody(t, response))
		}
		var person struct {
			ID       string `json:"id"`
			FullName string `json:"fullName"`
		}
		decodeBody(t, response, &person)
		return person.ID
	}

	firstID := createPerson(fmt.Sprintf("测试%d", suffix))
	secondID := createPerson(fmt.Sprintf("测试%dB", suffix))
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM spouse_relationships WHERE person_a_id IN (?, ?) OR person_b_id IN (?, ?)`, firstID, secondID, firstID, secondID)
		_, _ = db.DB.Exec(`DELETE FROM parent_child_relationships WHERE parent_id IN (?, ?) OR child_id IN (?, ?)`, firstID, secondID, firstID, secondID)
		_, _ = db.DB.Exec(`DELETE FROM persons WHERE id IN (?, ?)`, firstID, secondID)
	})

	body, _ := json.Marshal(map[string]any{
		"parentId":   "50000000-0000-4000-8000-000000000106",
		"childId":    firstID,
		"parentRole": "father",
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/relationships/parent-child", string(body), login.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("add parent-child status = %d, body = %s", response.StatusCode, readBody(t, response))
	}

	body, _ = json.Marshal(map[string]any{
		"personAId": firstID,
		"personBId": secondID,
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/relationships/spouse", string(body), login.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("add spouse status = %d, body = %s", response.StatusCode, readBody(t, response))
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/persons/"+firstID, "", login.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("get new person status = %d", response.StatusCode)
	}
	var person struct {
		Parents []any `json:"parents"`
		Spouses []any `json:"spouses"`
		Version int   `json:"version"`
	}
	decodeBody(t, response, &person)
	if len(person.Parents) != 1 || len(person.Spouses) != 1 || person.Version != 3 {
		t.Fatalf("unexpected new person: %+v", person)
	}
}
