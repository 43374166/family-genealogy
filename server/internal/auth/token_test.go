package auth

import "testing"

func TestSessionTokenIsOpaqueAndHashed(t *testing.T) {
	token, digest, err := NewSessionToken()
	if err != nil {
		t.Fatalf("NewSessionToken() error = %v", err)
	}
	if len(token) < 40 {
		t.Fatalf("token too short: %d", len(token))
	}
	if len(digest) != 32 {
		t.Fatalf("digest length = %d, want 32", len(digest))
	}
	if string(digest) == token {
		t.Fatal("digest must not equal the token")
	}
	again := HashSessionToken(token)
	if string(again) != string(digest) {
		t.Fatal("hash is not deterministic")
	}
}
