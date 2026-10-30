package httpapi_test

import (
	"context"
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

func TestBranchAdminManagement(t *testing.T) {
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

	loginName := fmt.Sprintf("manage_%d", time.Now().UnixNano())
	userID := registerInviteUser(t, server.URL, owner.Token, loginName, "member", "")
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM branch_admin_grants WHERE user_id = ?`, userID)
		_, _ = db.DB.Exec(`DELETE FROM family_memberships WHERE user_id = ?`, userID)
		_, _ = db.DB.Exec(`DELETE FROM users WHERE id = ?`, userID)
	})

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/branch-admins",
		fmt.Sprintf(`{"userId":%q,"branchId":"40000000-0000-4000-8000-000000000001","includeDescendants":true}`, userID),
		owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("grant status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var grant struct {
		ID         string `json:"id"`
		BranchName string `json:"branchName"`
	}
	decodeBody(t, response, &grant)
	if grant.ID == "" || grant.BranchName == "" {
		t.Fatalf("unexpected grant: %+v", grant)
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/branch-admins", "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("list grants status = %d", response.StatusCode)
	}
	var list struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	decodeBody(t, response, &list)
	if len(list.Items) == 0 {
		t.Fatal("grant list is empty")
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/accounts", "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("accounts status = %d", response.StatusCode)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/login",
		fmt.Sprintf(`{"loginName":%q,"password":"Member#2026"}`, loginName), "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("member login status = %d", response.StatusCode)
	}
	var member struct {
		Token string `json:"token"`
	}
	decodeBody(t, response, &member)

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/me", "", member.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("me status = %d", response.StatusCode)
	}
	var me struct {
		Membership struct {
			Role string `json:"role"`
		} `json:"membership"`
	}
	decodeBody(t, response, &me)
	if me.Membership.Role != "admin" {
		t.Fatalf("role after grant = %q", me.Membership.Role)
	}

	response = doJSON(t, http.DefaultClient, http.MethodDelete,
		server.URL+"/api/v1/branch-admins/"+grant.ID, "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("revoke status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/me", "", member.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("me after revoke status = %d", response.StatusCode)
	}
	decodeBody(t, response, &me)
	if me.Membership.Role != "member" {
		t.Fatalf("role after revoke = %q", me.Membership.Role)
	}
}
