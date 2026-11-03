package geoip

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestPrivateIPDoesNotLeaveTheProcess(t *testing.T) {
	client := New()
	client.lookupURL = "http://127.0.0.1:1/should-not-be-called/%s"
	location := client.Lookup(context.Background(), "127.0.0.1")
	if location.City != "本地网络" {
		t.Fatalf("private IP city = %q", location.City)
	}
	if location.Display() != "本地网络" {
		t.Fatalf("private IP display = %q", location.Display())
	}
}

func TestLookupParsesProviderResponse(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/203.0.113.9") {
			t.Fatalf("unexpected lookup path: %s", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"success","country":"中国","regionName":"山东省","city":"济南市"}`))
	}))
	defer server.Close()

	client := New()
	client.lookupURL = server.URL + "/%s"
	client.now = func() time.Time { return time.Now() }
	location := client.Lookup(context.Background(), "203.0.113.9")
	if location.Display() != "山东省·济南市" {
		t.Fatalf("location display = %q", location.Display())
	}
	cached, ok := client.fromCache("203.0.113.9")
	if !ok || cached.City != "济南市" {
		t.Fatalf("lookup result was not cached")
	}
}

func TestLookupFailureIsNonFatal(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "nope", http.StatusBadGateway)
	}))
	defer server.Close()
	client := New()
	client.lookupURL = server.URL + "/%s"
	location := client.Lookup(context.Background(), "203.0.113.10")
	if location.Display() != "" {
		t.Fatalf("expected empty location on failure, got %q", location.Display())
	}
}
