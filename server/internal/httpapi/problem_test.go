package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestProblemMessagesAreChinese(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/api/v1/test", nil)
	recorder := httptest.NewRecorder()
	writeProblem(recorder, request, http.StatusUnauthorized, "UNAUTHORIZED", "not authenticated")
	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d", recorder.Code)
	}
	var problem Problem
	if err := json.Unmarshal(recorder.Body.Bytes(), &problem); err != nil {
		t.Fatalf("decode problem: %v", err)
	}
	if problem.Detail != "请先登录" {
		t.Fatalf("detail = %q", problem.Detail)
	}
	if problem.Title != "请先登录" {
		t.Fatalf("title = %q", problem.Title)
	}
	if problem.Code != "UNAUTHORIZED" {
		t.Fatalf("code = %q", problem.Code)
	}
}

func TestProblemKeepsUnknownChineseDetail(t *testing.T) {
	if got := localizeProblemDetail("自定义中文提示"); got != "自定义中文提示" {
		t.Fatalf("detail changed: %q", got)
	}
	if got := localizeProblemDetail("some future English error"); got != "请求未完成，请稍后重试" {
		t.Fatalf("untracked English detail leaked: %q", got)
	}
}

func TestDecodeJSONErrorsAreChinese(t *testing.T) {
	request := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(`{"name":`))
	recorder := httptest.NewRecorder()
	var body map[string]any
	err := decodeJSON(recorder, request, &body)
	if err == nil {
		t.Fatal("malformed JSON was accepted")
	}
	if !strings.Contains(err.Error(), "请求") {
		t.Fatalf("unexpected error: %v", err)
	}
}
