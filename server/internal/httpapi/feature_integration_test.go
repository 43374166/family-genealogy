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
	"github.com/google/uuid"
)

func openTestServer(t *testing.T) (*httptest.Server, *database.DB) {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_DSN")
	if dsn == "" {
		t.Skip("TEST_DATABASE_DSN is not set; skip HTTP/MySQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	t.Cleanup(cancel)
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
	return server, db
}

func loginTestUser(t *testing.T, server *httptest.Server, loginName, password string) struct {
	Token string `json:"token"`
	User  struct {
		ID string `json:"id"`
	} `json:"user"`
	Family struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"family"`
} {
	t.Helper()
	var session struct {
		Token string `json:"token"`
		User  struct {
			ID string `json:"id"`
		} `json:"user"`
		Family struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"family"`
	}
	response := doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/auth/login",
		fmt.Sprintf(`{"loginName":%q,"password":%q}`, loginName, password), "")
	if response.StatusCode != http.StatusOK {
		t.Fatalf("login %s status = %d, body = %s", loginName, response.StatusCode, readBody(t, response))
	}
	decodeBody(t, response, &session)
	return session
}

func TestPhotoPeopleAndStoryPhotos(t *testing.T) {
	server, db := openTestServer(t)
	owner := loginTestUser(t, server, "linglei", "Demo#2026")

	response := doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/tree", "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("tree status = %d", response.StatusCode)
	}
	var tree struct {
		Persons []struct {
			ID       string `json:"id"`
			FullName string `json:"fullName"`
		} `json:"persons"`
	}
	decodeBody(t, response, &tree)
	if len(tree.Persons) < 2 {
		t.Fatalf("seed tree has %d persons; need at least 2", len(tree.Persons))
	}
	personA := tree.Persons[0].ID
	personB := tree.Persons[1].ID
	familyID := owner.Family.ID

	photoIDs := []string{uuid.NewString(), uuid.NewString(), uuid.NewString()}
	for index, photoID := range photoIDs {
		if _, err := db.DB.Exec(`
			INSERT INTO family_photos
				(id, family_id, person_id, uploaded_by_user_id, object_key,
				 content_type, size_bytes, caption)
			VALUES (?, ?, NULL, ?, ?, 'image/jpeg', 1024, ?)`,
			photoID, familyID, owner.User.ID,
			"test/"+photoID+".jpg", fmt.Sprintf("多人物照片 %d", index),
		); err != nil {
			t.Fatalf("insert test photo: %v", err)
		}
	}
	tags := map[string][]string{
		photoIDs[0]: {personA},
		photoIDs[1]: {personA, personB},
		photoIDs[2]: {personB},
	}
	for photoID, personIDs := range tags {
		for _, personID := range personIDs {
			if _, err := db.DB.Exec(`
				INSERT INTO family_photo_people (photo_id, person_id, family_id)
				VALUES (?, ?, ?)`, photoID, personID, familyID,
			); err != nil {
				t.Fatalf("insert photo person: %v", err)
			}
		}
	}
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM family_story_photos WHERE photo_id IN (?, ?, ?)`,
			photoIDs[0], photoIDs[1], photoIDs[2])
		_, _ = db.DB.Exec(`DELETE FROM family_photo_people WHERE photo_id IN (?, ?, ?)`,
			photoIDs[0], photoIDs[1], photoIDs[2])
		_, _ = db.DB.Exec(`DELETE FROM family_photos WHERE id IN (?, ?, ?)`,
			photoIDs[0], photoIDs[1], photoIDs[2])
	})

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/photos?personIds="+personA, "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("list photos status = %d", response.StatusCode)
	}
	var page struct {
		Items []struct {
			ID      string `json:"id"`
			Persons []struct {
				PersonID string `json:"personId"`
			} `json:"persons"`
		} `json:"items"`
	}
	decodeBody(t, response, &page)
	found := map[string]int{}
	for _, item := range page.Items {
		for _, photoID := range photoIDs {
			if item.ID == photoID {
				found[photoID] = len(item.Persons)
			}
		}
	}
	if found[photoIDs[0]] != 1 || found[photoIDs[1]] != 2 {
		t.Fatalf("person filter did not return multi-person tags: %+v", found)
	}
	if _, ok := found[photoIDs[2]]; ok {
		t.Fatalf("photo tagged only with person B returned for person A")
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/photos?solePersonId="+personA, "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("list sole photos status = %d", response.StatusCode)
	}
	var solePage struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	decodeBody(t, response, &solePage)
	soleIDs := map[string]bool{}
	for _, item := range solePage.Items {
		for _, photoID := range photoIDs {
			if item.ID == photoID {
				soleIDs[photoID] = true
			}
		}
	}
	if !soleIDs[photoIDs[0]] || soleIDs[photoIDs[1]] {
		t.Fatalf("sole person filter returned wrong photos: %+v", soleIDs)
	}

	response = doJSON(t, http.DefaultClient, http.MethodPatch,
		server.URL+"/api/v1/photos/"+photoIDs[0],
		fmt.Sprintf(`{"personIds":["%s","%s"],"caption":"更新后","takenAt":""}`, personA, personB),
		owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("update photo status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var updated struct {
		Persons []struct {
			PersonID string `json:"personId"`
		} `json:"persons"`
	}
	decodeBody(t, response, &updated)
	if len(updated.Persons) != 2 {
		t.Fatalf("updated photo people = %+v", updated.Persons)
	}

	storyBody := fmt.Sprintf(`{"title":"多图故事","body":"带两张配图","personId":"%s","photoIds":["%s","%s"]}`,
		personA, photoIDs[0], photoIDs[2])
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/stories", storyBody, owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create story status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var story struct {
		ID     string `json:"id"`
		Photos []struct {
			ID string `json:"id"`
		} `json:"photos"`
	}
	decodeBody(t, response, &story)
	if len(story.Photos) != 2 {
		t.Fatalf("story photos = %d, want 2", len(story.Photos))
	}
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM family_story_photos WHERE story_id = ?`, story.ID)
		_, _ = db.DB.Exec(`DELETE FROM family_stories WHERE id = ?`, story.ID)
	})
	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/stories/"+story.ID, "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("get story status = %d", response.StatusCode)
	}
	var fetched struct {
		Photos []struct {
			ID string `json:"id"`
		} `json:"photos"`
	}
	decodeBody(t, response, &fetched)
	if len(fetched.Photos) != 2 {
		t.Fatalf("fetched story photos = %d, want 2", len(fetched.Photos))
	}
}

func TestJoinFamilyMergeWorkflow(t *testing.T) {
	server, db := openTestServer(t)
	owner := loginTestUser(t, server, "linglei", "Demo#2026")

	response := doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/invites",
		`{"role":"member","maxUses":1,"expiresInDays":1}`, owner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create invite status = %d", response.StatusCode)
	}
	var invite struct {
		Code string `json:"code"`
	}
	decodeBody(t, response, &invite)

	suffix := time.Now().UnixNano()
	loginName := fmt.Sprintf("merge_%d", suffix)
	familyName := fmt.Sprintf("合并测试家族_%d", suffix)
	registerBody, _ := json.Marshal(map[string]any{
		"loginName": loginName, "password": "Member#2026",
		"displayName": "合并测试", "familyName": familyName, "surname": "凌",
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
		Family struct {
			ID string `json:"id"`
		} `json:"family"`
	}
	decodeBody(t, response, &registered)
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM user_sessions WHERE user_id = ?`, registered.User.ID)
		_, _ = db.DB.Exec(`DELETE FROM notifications WHERE user_id = ?`, registered.User.ID)
		_, _ = db.DB.Exec(`DELETE FROM family_memberships WHERE user_id = ?`, registered.User.ID)
		_, _ = db.DB.Exec(`DELETE FROM users WHERE id = ?`, registered.User.ID)
	})
	joiner := loginTestUser(t, server, loginName, "Member#2026")

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/branches", "", joiner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("branches status = %d", response.StatusCode)
	}
	var branchPage struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	decodeBody(t, response, &branchPage)
	if len(branchPage.Items) == 0 {
		t.Fatal("new family has no branch")
	}
	personName := fmt.Sprintf("合并人物%d", suffix)
	personBody, _ := json.Marshal(map[string]any{
		"surname": "凌", "givenName": personName, "gender": "male",
		"generationNo": 1, "branchId": branchPage.Items[0].ID,
		"lifeStatus": "living",
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/persons", string(personBody), joiner.Token)
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("create person status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var createdPerson struct {
		ID string `json:"id"`
	}
	decodeBody(t, response, &createdPerson)

	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/families/join",
		fmt.Sprintf(`{"inviteCode":%q}`, invite.Code), joiner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("join family status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var joined struct {
		Family struct {
			ID string `json:"id"`
		} `json:"family"`
		Families []struct {
			Family struct {
				ID string `json:"id"`
			} `json:"family"`
		} `json:"families"`
		MergeRequests []struct {
			ID             string `json:"id"`
			SourceFamilyID string `json:"sourceFamilyId"`
			PersonCount    int    `json:"personCount"`
			Status         string `json:"status"`
		} `json:"mergeRequests"`
	}
	decodeBody(t, response, &joined)
	if joined.Family.ID != owner.Family.ID || len(joined.Families) != 2 {
		t.Fatalf("join did not keep data family: %+v", joined)
	}
	if len(joined.MergeRequests) != 1 ||
		joined.MergeRequests[0].SourceFamilyID != registered.Family.ID ||
		joined.MergeRequests[0].PersonCount != 1 ||
		joined.MergeRequests[0].Status != "pending" {
		t.Fatalf("merge request not created: %+v", joined.MergeRequests)
	}
	requestID := joined.MergeRequests[0].ID
	t.Cleanup(func() {
		_, _ = db.DB.Exec(`DELETE FROM family_merge_requests WHERE id = ?`, requestID)
	})

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/merge-requests?status=pending", "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("list merge requests status = %d", response.StatusCode)
	}
	var list struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	decodeBody(t, response, &list)
	if len(list.Items) == 0 {
		t.Fatal("owner did not see merge request")
	}
	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/merge-requests/"+requestID, "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("merge detail status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var detail struct {
		Persons []struct {
			ID string `json:"id"`
		} `json:"persons"`
		Branches []struct {
			ID string `json:"id"`
		} `json:"branches"`
		MinGeneration int `json:"minGeneration"`
	}
	decodeBody(t, response, &detail)
	if len(detail.Persons) != 1 || len(detail.Branches) == 0 {
		t.Fatalf("merge detail incomplete: %+v", detail)
	}

	approveBody, _ := json.Marshal(map[string]any{
		"personIds":       []string{detail.Persons[0].ID},
		"targetBranchId":  detail.Branches[0].ID,
		"startGeneration": 1,
		"note":            "合并测试",
	})
	response = doJSON(t, http.DefaultClient, http.MethodPost,
		server.URL+"/api/v1/merge-requests/"+requestID+"/approve",
		string(approveBody), owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("approve merge status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var result struct {
		ImportedPersons int  `json:"importedPersons"`
		SourceArchived  bool `json:"sourceArchived"`
		Request         struct {
			Status string `json:"status"`
		} `json:"request"`
	}
	decodeBody(t, response, &result)
	if result.ImportedPersons != 1 || !result.SourceArchived || result.Request.Status != "approved" {
		t.Fatalf("unexpected merge result: %+v", result)
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/tree", "", owner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("tree after merge status = %d", response.StatusCode)
	}
	var tree struct {
		Persons []struct {
			FullName string `json:"fullName"`
		} `json:"persons"`
	}
	decodeBody(t, response, &tree)
	found := false
	for _, person := range tree.Persons {
		if person.FullName == "凌"+personName {
			found = true
		}
	}
	if !found {
		t.Fatalf("merged person not found in target tree")
	}

	response = doJSON(t, http.DefaultClient, http.MethodGet,
		server.URL+"/api/v1/families", "", joiner.Token)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("joiner families status = %d", response.StatusCode)
	}
	var families struct {
		Items []struct {
			Family struct {
				ID string `json:"id"`
			} `json:"family"`
		} `json:"items"`
	}
	decodeBody(t, response, &families)
	if len(families.Items) != 1 || families.Items[0].Family.ID != owner.Family.ID {
		t.Fatalf("source family was not archived for joiner: %+v", families.Items)
	}

	// Best-effort cleanup of the imported person. Audit rows stay append-only.
	var importedID string
	if err := db.DB.QueryRow(`
		SELECT id FROM persons
		WHERE family_id = ? AND full_name = ? LIMIT 1`,
		owner.Family.ID, "凌"+personName,
	).Scan(&importedID); err == nil && importedID != "" {
		_, _ = db.DB.Exec(`DELETE FROM parent_child_relationships
			WHERE parent_id = ? OR child_id = ?`, importedID, importedID)
		_, _ = db.DB.Exec(`DELETE FROM spouse_relationships
			WHERE person_a_id = ? OR person_b_id = ?`, importedID, importedID)
		_, _ = db.DB.Exec(`DELETE FROM persons WHERE id = ?`, importedID)
	}
	_ = createdPerson
}
