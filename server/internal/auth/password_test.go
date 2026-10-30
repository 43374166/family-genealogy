package auth

import "testing"

func TestPasswordHashRoundTrip(t *testing.T) {
	hash, err := HashPassword("correct horse battery staple")
	if err != nil {
		t.Fatalf("HashPassword() error = %v", err)
	}
	ok, err := VerifyPassword(hash, "correct horse battery staple")
	if err != nil || !ok {
		t.Fatalf("VerifyPassword(correct) = %v, %v", ok, err)
	}
	ok, err = VerifyPassword(hash, "wrong password")
	if err != nil {
		t.Fatalf("VerifyPassword(wrong) error = %v", err)
	}
	if ok {
		t.Fatal("wrong password accepted")
	}
}

func TestPasswordRejectsShortInput(t *testing.T) {
	if _, err := HashPassword("short"); err == nil {
		t.Fatal("expected short password to be rejected")
	}
}

func TestVerifyRejectsMalformedHash(t *testing.T) {
	for _, hash := range []string{"", "plaintext", "$argon2id$v=19$m=65536,t=3,p=2$bad$bad"} {
		if _, err := VerifyPassword(hash, "password"); err == nil {
			t.Fatalf("malformed hash %q accepted", hash)
		}
	}
}
