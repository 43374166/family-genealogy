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

func TestInviteRegistrationAndBinding(t *testing.T) {
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

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/invites",
		`{"role":"member","maxUses":1,"expiresInDays":1}`, owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create invite status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var invite struct {
		Code string `json:"code"`
	}
	decodeBody(t, response, &invite)
	if invite.Code == "" {
		t.Fatal("invite code is empty")
	}

	suffix := time.Now().UnixNano()
	loginName := fmt.Sprintf("member_%d", suffix)
	registerBody, _ := json.Marshal(map[string]any{
		"loginName":   loginName,
		"password":    "Member#2026",
		"displayName": "测试成员",
		"inviteCode":  invite.Code,
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/register", string(registerBody), "")
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("register status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var registered struct {
		User struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	decodeBody(t, response, &registered)
	if registered.User.ID == "" {
		t.Fatal("registered user id missing")
	}
	var userID = registered.User.ID
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM person_binding_requests WHERE requester_user_id = ?`, userID)
		_, _ = db.DB.Exec(`DELETE FROM family_memberships WHERE user_id = ?`, userID)
		_, _ = db.DB.Exec(`DELETE FROM users WHERE id = ?`, userID)
	})

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/login",
		fmt.Sprintf(`{"loginName":%q,"password":"Member#2026"}`, loginName), "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("member login status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var member struct {
		Token string `json:"token"`
	}
	decodeBody(t, response, &member)

	const personID = "50000000-0000-4000-8000-000000000105"
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/bind-requests",
		fmt.Sprintf(`{"personId":%q}`, personID), member.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("binding request status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var binding struct {
		ID     string `json:"id"`
		Status string `json:"status"`
	}
	decodeBody(t, response, &binding)
	if binding.Status != "pending" {
		t.Fatalf("binding status = %q", binding.Status)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/bind-requests/"+binding.ID+"/approve",
		`{"note":"核对身份通过"}`, owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("approve binding status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/me", "", member.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("member me status = %d", response.StatusCode)
	}
	var me struct {
		Membership struct {
			PersonID *string `json:"personId"`
		} `json:"membership"`
	}
	decodeBody(t, response, &me)
	if me.Membership.PersonID == nil || *me.Membership.PersonID != personID {
		t.Fatalf("binding not applied: %+v", me.Membership.PersonID)
	}
}
