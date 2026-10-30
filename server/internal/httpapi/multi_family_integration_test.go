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

func TestOpenRegistrationAndFamilySwitch(t *testing.T) {
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

	suffix := time.Now().UnixNano()
	loginName := fmt.Sprintf("open_%d", suffix)
	registerBody, _ := json.Marshal(map[string]any{
		"loginName": loginName, "password": "Member#2026",
		"displayName": "开放用户", "familyName": "开放测试家族", "surname": "凌",
	})
	response := doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/register", string(registerBody), "")
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("open register status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var registered struct {
		User struct {
			ID string `json:"id"`
		} `json:"user"`
		Family struct {
			ID string `json:"id"`
		} `json:"family"`
	}
	decodeBody(t, response, &registered)
	if registered.User.ID == "" || registered.Family.ID == "" {
		t.Fatalf("unexpected open registration: %+v", registered)
	}
	userID := registered.User.ID
	firstFamilyID := registered.Family.ID
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM user_sessions WHERE user_id = ?`, userID)
		_, _ = db.DB.Exec(`DELETE FROM family_memberships WHERE user_id = ?`, userID)
		_, _ = db.DB.Exec(`DELETE FROM audit_logs WHERE family_id IN (SELECT id FROM families WHERE name = '开放测试家族')`)
		_, _ = db.DB.Exec(`DELETE FROM audit_logs WHERE actor_user_id = ?`, userID)
		_, _ = db.DB.Exec(`DELETE FROM users WHERE id = ?`, userID)
		_, _ = db.DB.Exec(`DELETE FROM branches WHERE family_id IN (SELECT id FROM families WHERE name = '开放测试家族')`)
		_, _ = db.DB.Exec(`DELETE FROM families WHERE name = '开放测试家族'`)
	})

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/login",
		fmt.Sprintf(`{"loginName":%q,"password":"Member#2026"}`, loginName), "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("open user login status = %d", response.StatusCode)
	}
	var session struct {
		Token string `json:"token"`
	}
	decodeBody(t, response, &session)

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/me", "", session.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("me status = %d", response.StatusCode)
	}
	var me struct {
		Family struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"family"`
		Membership struct {
			Role string `json:"role"`
		} `json:"membership"`
		Families []struct {
			Family struct {
				ID string `json:"id"`
			} `json:"family"`
		} `json:"families"`
	}
	decodeBody(t, response, &me)
	if me.Family.ID != firstFamilyID || me.Membership.Role != "owner" || len(me.Families) != 1 {
		t.Fatalf("unexpected initial me: %+v", me)
	}

	createBody, _ := json.Marshal(map[string]any{
		"name": "第二家族", "surname": "凌",
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/families", string(createBody), session.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create second family status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var second struct {
		Family struct {
			ID string `json:"id"`
		} `json:"family"`
	}
	decodeBody(t, response, &second)
	if second.Family.ID == "" {
		t.Fatal("second family id missing")
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/me", "", session.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("me after create status = %d", response.StatusCode)
	}
	decodeBody(t, response, &me)
	if me.Family.ID != second.Family.ID || len(me.Families) != 2 {
		t.Fatalf("did not switch to second family: %+v", me)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/switch-family",
		fmt.Sprintf(`{"familyId":%q}`, firstFamilyID), session.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("switch first family status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	decodeBody(t, response, &me)
	if me.Family.ID != firstFamilyID {
		t.Fatalf("did not switch back to first family: %+v", me)
	}
}
