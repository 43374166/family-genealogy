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

func TestImportPackage(t *testing.T) {
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

	var owner struct {
		Token string `json:"token"`
	}
	ownerID := "20000000-0000-4000-8000-000000000001"
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM user_sessions WHERE user_id = ?`, ownerID)
	})
	response := doJSON(t, http.DefaultClient, http.MethodPost, server.URL+"/api/v1/auth/login",
		`{"loginName":"linglei","password":"Demo#2026"}`, "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("owner login status = %d", response.StatusCode)
	}
	decodeBody(t, response, &owner)

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/import-packages",
		`{"rootPersonId":"50000000-0000-4000-8000-000000000105"}`, owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create import package status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var pkg struct {
		Code        string `json:"code"`
		PersonCount int    `json:"personCount"`
	}
	decodeBody(t, response, &pkg)
	if pkg.Code == "" || pkg.PersonCount != 1 {
		t.Fatalf("unexpected package: %+v", pkg)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/import-packages/preview",
		fmt.Sprintf(`{"code":%q}`, pkg.Code), owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("preview import package status = %d, body = %s", response.StatusCode, readBody(t, response))
	}

	createFamilyBody, _ := json.Marshal(map[string]any{
		"name": "导入目标家族", "surname": "凌",
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/families", string(createFamilyBody), owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create import target family status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var target struct {
		Family struct {
			ID string `json:"id"`
		} `json:"family"`
	}
	decodeBody(t, response, &target)
	if target.Family.ID == "" {
		t.Fatal("target family id missing")
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/branches", "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("target branches status = %d", response.StatusCode)
	}
	var branches struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	decodeBody(t, response, &branches)
	if len(branches.Items) == 0 {
		t.Fatal("target branch missing")
	}

	importBody, _ := json.Marshal(map[string]any{
		"code": pkg.Code, "branchId": branches.Items[0].ID, "rootGeneration": 1,
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/import-packages/import", string(importBody), owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("import package status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var result struct {
		PersonCount int `json:"personCount"`
	}
	decodeBody(t, response, &result)
	if result.PersonCount != 1 {
		t.Fatalf("imported person count = %d", result.PersonCount)
	}
	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/tree", "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("target tree status = %d", response.StatusCode)
	}
	var tree struct {
		Persons []struct {
			ID string `json:"id"`
		} `json:"persons"`
	}
	decodeBody(t, response, &tree)
	if len(tree.Persons) != 1 {
		t.Fatalf("target tree persons = %d", len(tree.Persons))
	}

	// Clean up the test target family while leaving the source family intact.
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/switch-family",
		`{"familyId":"10000000-0000-4000-8000-000000000001"}`, owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("switch back source status = %d", response.StatusCode)
	}
	_, _ = db.DB.Exec(`UPDATE families SET status = 'archived' WHERE id = ?`, target.Family.ID)
}
