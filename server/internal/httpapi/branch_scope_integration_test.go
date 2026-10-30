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

func TestBranchAdminScope(t *testing.T) {
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
	adminLogin := fmt.Sprintf("branchadmin_%d", suffix)
	memberLogin := fmt.Sprintf("branchmember_%d", suffix)
	adminID := registerInviteUser(t, server.URL, owner.Token, adminLogin, "admin",
		"40000000-0000-4000-8000-000000000001")
	memberID := registerInviteUser(t, server.URL, owner.Token, memberLogin, "member", "")
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM person_binding_requests WHERE requester_user_id = ?`, memberID)
		_, _ = db.DB.Exec(`DELETE FROM branch_admin_grants WHERE user_id = ?`, adminID)
		_, _ = db.DB.Exec(`DELETE FROM family_memberships WHERE user_id IN (?, ?)`, adminID, memberID)
		_, _ = db.DB.Exec(`DELETE FROM users WHERE id IN (?, ?)`, adminID, memberID)
	})

	var admin struct {
		Token string `json:"token"`
	}
	response = doJSON(t, http.DefaultClient, http.MethodPost, server.URL+"/api/v1/auth/login",
		fmt.Sprintf(`{"loginName":%q,"password":"Member#2026"}`, adminLogin), "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("admin login status = %d", response.StatusCode)
	}
	decodeBody(t, response, &admin)

	var member struct {
		Token string `json:"token"`
	}
	response = doJSON(t, http.DefaultClient, http.MethodPost, server.URL+"/api/v1/auth/login",
		fmt.Sprintf(`{"loginName":%q,"password":"Member#2026"}`, memberLogin), "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("member login status = %d", response.StatusCode)
	}
	decodeBody(t, response, &member)

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/bind-requests",
		`{"personId":"50000000-0000-4000-8000-000000000105"}`, member.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("out-of-scope binding request status = %d, body = %s",
			response.StatusCode, readBody(t, response))
	}
	var outOfScope struct {
		ID string `json:"id"`
	}
	decodeBody(t, response, &outOfScope)
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/bind-requests/"+outOfScope.ID+"/approve",
		`{"note":"同意"}`, admin.Token)
	if response.StatusCode != http.StatusForbidden {
		t.Fatalf("out-of-scope approval status = %d, body = %s",
			response.StatusCode, readBody(t, response))
	}
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/bind-requests/"+outOfScope.ID+"/reject",
		`{"note":"不在管辖支"}`, owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("owner reject status = %d", response.StatusCode)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/bind-requests",
		`{"personId":"50000000-0000-4000-8000-000000000106"}`, member.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("in-scope binding request status = %d, body = %s",
			response.StatusCode, readBody(t, response))
	}
	var inScope struct {
		ID string `json:"id"`
	}
	decodeBody(t, response, &inScope)
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/bind-requests/"+inScope.ID+"/approve",
		`{"note":"在成铭支范围内"}`, admin.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("in-scope approval status = %d, body = %s",
			response.StatusCode, readBody(t, response))
	}
}

func registerInviteUser(
	t *testing.T,
	serverURL, ownerToken, loginName, role, branchID string,
) string {
	t.Helper()
	inviteBody, _ := json.Marshal(map[string]any{
		"role": role, "branchId": branchID, "maxUses": 1, "expiresInDays": 1,
	})
	response := doJSON(t, http.DefaultClient, http.MethodPost,
		serverURL+"/api/v1/invites", string(inviteBody), ownerToken)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create %s invite status = %d, body = %s",
			role, response.StatusCode, readBody(t, response))
	}
	var invite struct {
		Code string `json:"code"`
	}
	decodeBody(t, response, &invite)
	registerBody, _ := json.Marshal(map[string]any{
		"loginName": loginName, "password": "Member#2026",
		"displayName": "测试" + role, "inviteCode": invite.Code,
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		serverURL+"/api/v1/auth/register", string(registerBody), "")
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("register %s status = %d, body = %s",
			role, response.StatusCode, readBody(t, response))
	}
	var registered struct {
		User struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	decodeBody(t, response, &registered)
	return registered.User.ID
}
