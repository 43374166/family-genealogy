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

func TestPersonEditAndRelationshipDelete(t *testing.T) {
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
	response := doJSON(t, http.DefaultClient, http.MethodPost, server.URL+"/api/v1/auth/login",
		`{"loginName":"linglei","password":"Demo#2026"}`, "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("owner login status = %d", response.StatusCode)
	}
	decodeBody(t, response, &owner)

	suffix := time.Now().UnixNano()
	createBody, _ := json.Marshal(map[string]any{
		"surname": "凌", "givenName": fmt.Sprintf("编辑%d", suffix),
		"gender": "male", "generationNo": 3,
		"branchId": "40000000-0000-4000-8000-000000000002",
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/persons", string(createBody), owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create person status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var created struct {
		ID      string `json:"id"`
		Version int    `json:"version"`
	}
	decodeBody(t, response, &created)
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM parent_child_relationships WHERE parent_id = ? OR child_id = ?`, created.ID, created.ID)
		_, _ = db.DB.Exec(`DELETE FROM spouse_relationships WHERE person_a_id = ? OR person_b_id = ?`, created.ID, created.ID)
		_, _ = db.DB.Exec(`DELETE FROM persons WHERE id = ?`, created.ID)
	})

	updateBody, _ := json.Marshal(map[string]any{
		"surname": "凌", "givenName": "编辑后", "courtesyName": "字",
		"gender": "male", "generationNo": 3,
		"branchId":  "40000000-0000-4000-8000-000000000002",
		"birthYear": 1990, "lifeStatus": "living",
		"birthPlace": "测试出生地", "biography": "测试传记",
		"version": created.Version,
	})
	response = doJSON(t, http.DefaultClient, http.MethodPatch,
		server.URL+"/api/v1/persons/"+created.ID, string(updateBody), owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("update person status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var updated struct {
		GivenName string `json:"givenName"`
		Version   int    `json:"version"`
	}
	decodeBody(t, response, &updated)
	if updated.GivenName != "编辑后" || updated.Version != created.Version+1 {
		t.Fatalf("unexpected updated person: %+v", updated)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/relationships/parent-child",
		fmt.Sprintf(`{"parentId":"50000000-0000-4000-8000-000000000101","childId":%q,"parentRole":"father"}`, created.ID),
		owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("add parent status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/persons/"+created.ID, "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("get person status = %d", response.StatusCode)
	}
	var detail struct {
		Parents []struct {
			EdgeID string `json:"edgeId"`
		} `json:"parents"`
	}
	decodeBody(t, response, &detail)
	if len(detail.Parents) != 1 || detail.Parents[0].EdgeID == "" {
		t.Fatalf("parent edge missing: %+v", detail.Parents)
	}
	response = doJSON(t, http.DefaultClient, http.MethodDelete,
		server.URL+"/api/v1/relationships/parent-child/"+detail.Parents[0].EdgeID, "", owner.Token)
	if response.StatusCode != http.StatusNoContent {
		t.Fatalf("delete parent status = %d, body = %s", response.StatusCode, readBody(t, response))
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/relationships/spouse",
		fmt.Sprintf(`{"personAId":%q,"personBId":"50000000-0000-4000-8000-000000000118"}`, created.ID),
		owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("add spouse status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/persons/"+created.ID, "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("get spouse detail status = %d", response.StatusCode)
	}
	var spouseDetail struct {
		Spouses []struct {
			EdgeID string `json:"edgeId"`
		} `json:"spouses"`
	}
	decodeBody(t, response, &spouseDetail)
	if len(spouseDetail.Spouses) != 1 || spouseDetail.Spouses[0].EdgeID == "" {
		t.Fatalf("spouse edge missing: %+v", spouseDetail.Spouses)
	}
	response = doJSON(t, http.DefaultClient, http.MethodDelete,
		server.URL+"/api/v1/relationships/spouse/"+spouseDetail.Spouses[0].EdgeID, "", owner.Token)
	if response.StatusCode != http.StatusNoContent {
		t.Fatalf("delete spouse status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
}
