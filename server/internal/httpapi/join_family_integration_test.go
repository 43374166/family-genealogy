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

func TestJoinFamilyWithInvite(t *testing.T) {
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

	suffix := time.Now().UnixNano()
	loginName := fmt.Sprintf("joiner_%d", suffix)
	registerBody, _ := json.Marshal(map[string]any{
		"loginName": loginName, "password": "Member#2026",
		"displayName": "加入测试", "familyName": "加入测试家族", "surname": "凌",
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/register", string(registerBody), "")
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("register joiner status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var registered struct {
		User struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	decodeBody(t, response, &registered)
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM user_sessions WHERE user_id = ?`, registered.User.ID)
		_, _ = db.DB.Exec(`DELETE FROM family_memberships WHERE user_id = ?`, registered.User.ID)
		_, _ = db.DB.Exec(`DELETE FROM audit_logs WHERE actor_user_id = ?`, registered.User.ID)
		_, _ = db.DB.Exec(`DELETE FROM users WHERE id = ?`, registered.User.ID)
		_, _ = db.DB.Exec(`UPDATE families SET status = 'archived' WHERE name = '加入测试家族'`)
	})

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/login",
		fmt.Sprintf(`{"loginName":%q,"password":"Member#2026"}`, loginName), "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("joiner login status = %d", response.StatusCode)
	}
	var session struct {
		Token string `json:"token"`
	}
	decodeBody(t, response, &session)

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/families/join",
		fmt.Sprintf(`{"inviteCode":%q}`, invite.Code), session.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("join family status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var me struct {
		Family struct {
			Name string `json:"name"`
		} `json:"family"`
		Families []struct {
			Family struct {
				Name string `json:"name"`
			} `json:"family"`
		} `json:"families"`
	}
	decodeBody(t, response, &me)
	if me.Family.Name != "凌氏家族" || len(me.Families) != 2 {
		t.Fatalf("join did not switch family: %+v", me)
	}
	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/tree", "", session.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("joined tree status = %d", response.StatusCode)
	}
	var tree struct {
		Persons []struct {
			ID string `json:"id"`
		} `json:"persons"`
	}
	decodeBody(t, response, &tree)
	if len(tree.Persons) != 22 {
		t.Fatalf("joined tree persons = %d", len(tree.Persons))
	}
}
