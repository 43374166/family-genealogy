package httpapi_test

import (
	"bytes"
	"context"
	"encoding/json"
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

func TestLoginAndReadOnlyAPI(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_DSN")
	if dsn == "" {
		t.Skip("TEST_DATABASE_DSN is not set; skip HTTP/MySQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	db, err := database.Open(ctx, dsn, 2)
	if err != nil {
		t.Fatalf("open test database: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	router := httpapi.NewRouter(httpapi.Dependencies{
		DB:     db,
		Store:  store.New(db.DB),
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
	server := httptest.NewServer(router)
	t.Cleanup(server.Close)

	var login struct {
		Token  string `json:"token"`
		Family struct {
			ID string `json:"id"`
		} `json:"family"`
	}
	response := doJSON(t, http.DefaultClient, http.MethodPost, server.URL+"/api/v1/auth/login",
		`{"loginName":"zhangsan","password":"Demo#2026"}`, "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("login status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	decodeBody(t, response, &login)
	if login.Token == "" {
		t.Fatal("login did not return a token")
	}
	if login.Family.ID == "" {
		t.Fatal("login did not return a family")
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet, server.URL+"/api/v1/tree", "", login.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("tree status = %d", response.StatusCode)
	}
	var tree struct {
		FamilyID    string `json:"familyId"`
		Persons     []any  `json:"persons"`
		ParentChild []any  `json:"parentChild"`
		Spouses     []any  `json:"spouses"`
	}
	decodeBody(t, response, &tree)
	if tree.FamilyID != login.Family.ID {
		t.Fatalf("tree familyId = %q, want %q", tree.FamilyID, login.Family.ID)
	}
	if len(tree.Persons) != 15 || len(tree.ParentChild) != 18 || len(tree.Spouses) != 3 {
		t.Fatalf("unexpected tree shape: persons=%d parentChild=%d spouses=%d",
			len(tree.Persons), len(tree.ParentChild), len(tree.Spouses))
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/persons?q=%E5%BC%A0%E4%B8%80", "", login.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("persons status = %d", response.StatusCode)
	}
	var page struct {
		Items []struct {
			FullName string `json:"fullName"`
		} `json:"items"`
	}
	decodeBody(t, response, &page)
	if len(page.Items) == 0 || page.Items[0].FullName != "张一" {
		t.Fatalf("unexpected person search result: %+v", page.Items)
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/persons/50000000-0000-4000-8000-000000000005", "", login.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("person detail status = %d", response.StatusCode)
	}
	var person struct {
		FullName string `json:"fullName"`
		Parents  []any  `json:"parents"`
		Children []any  `json:"children"`
		Spouses  []any  `json:"spouses"`
	}
	decodeBody(t, response, &person)
	if person.FullName != "张一" || len(person.Parents) != 2 || len(person.Children) != 5 || len(person.Spouses) != 1 {
		t.Fatalf("unexpected person detail: %+v", person)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost, server.URL+"/api/v1/auth/logout", "", login.Token)
	if response.StatusCode != http.StatusNoContent {
		t.Fatalf("logout status = %d", response.StatusCode)
	}
	response = doJSON(t, http.DefaultClient, http.MethodGet, server.URL+"/api/v1/me", "", login.Token)
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("me after logout status = %d, want 401", response.StatusCode)
	}
}

func TestReadAPIRequiresBearerToken(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_DSN")
	if dsn == "" {
		t.Skip("TEST_DATABASE_DSN is not set; skip HTTP/MySQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
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

	response := doJSON(t, http.DefaultClient, http.MethodGet, server.URL+"/api/v1/tree", "", "")
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unauthenticated tree status = %d, want 401", response.StatusCode)
	}
}

func doJSON(t *testing.T, client *http.Client, method, url, body, token string) *http.Response {
	t.Helper()
	request, err := http.NewRequest(method, url, bytes.NewBufferString(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if body != "" {
		request.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	response, err := client.Do(request)
	if err != nil {
		t.Fatalf("request %s %s: %v", method, url, err)
	}
	return response
}

func decodeBody(t *testing.T, response *http.Response, destination any) {
	t.Helper()
	defer response.Body.Close()
	if err := json.NewDecoder(response.Body).Decode(destination); err != nil {
		t.Fatalf("decode response: %v", err)
	}
}

func readBody(t *testing.T, response *http.Response) string {
	t.Helper()
	defer response.Body.Close()
	data, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatalf("read response: %v", err)
	}
	return string(data)
}
