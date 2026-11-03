package httpapi

import (
	"net/url"
	"testing"
)

func TestWebLoginPayloadCanBeParsedByClient(t *testing.T) {
	payload := webLoginPayload("qr-id", "secret-value")
	parsed, err := url.Parse(payload)
	if err != nil {
		t.Fatalf("parse payload: %v", err)
	}
	if parsed.Scheme != "familytree" || parsed.Host != "web-login" {
		t.Fatalf("unexpected payload scheme/host: %s", payload)
	}
	query := parsed.Query()
	if query.Get("v") != "1" || query.Get("id") != "qr-id" || query.Get("secret") != "secret-value" {
		t.Fatalf("unexpected payload query: %s", payload)
	}
}

func TestDescribeUserAgent(t *testing.T) {
	cases := []struct {
		userAgent string
		want      string
	}{
		{"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36", "Chrome · Windows"},
		{"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Firefox/133.0", "Firefox · macOS"},
		{"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) CriOS/130.0 Mobile/15E148 Safari/604.1", "Chrome · iOS"},
		{"Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/131.0 Mobile Safari/537.36", "Chrome · Android"},
		{"curl/8.6.0", "命令行"},
		{"", "未知设备"},
	}
	for _, tc := range cases {
		if got := describeUserAgent(tc.userAgent); got != tc.want {
			t.Fatalf("describeUserAgent(%q) = %q, want %q", tc.userAgent, got, tc.want)
		}
	}
}

func TestValidQRSecret(t *testing.T) {
	if validQRSecret("short") {
		t.Fatal("short QR secret accepted")
	}
	if !validQRSecret("abcdefghijklmnopqrstuvwxyz0123456789") {
		t.Fatal("valid QR secret rejected")
	}
}
