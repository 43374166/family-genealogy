package auth

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"golang.org/x/crypto/argon2"
)

const (
	argonMemory      uint32 = 64 * 1024
	argonIterations  uint32 = 3
	argonParallelism uint8  = 2
	argonSaltLength         = 16
	argonKeyLength          = 32
)

var ErrInvalidPasswordHash = errors.New("invalid password hash")

// HashPassword returns a self-describing Argon2id PHC string.
func HashPassword(password string) (string, error) {
	if len(password) < 8 || len(password) > 256 {
		return "", errors.New("password must be between 8 and 256 characters")
	}

	salt := make([]byte, argonSaltLength)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("generate salt: %w", err)
	}
	key := argon2.IDKey([]byte(password), salt, argonIterations, argonMemory, argonParallelism, argonKeyLength)

	return fmt.Sprintf(
		"$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
		argonMemory,
		argonIterations,
		argonParallelism,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(key),
	), nil
}

// VerifyPassword checks an Argon2id PHC string in constant time.
func VerifyPassword(encoded, password string) (bool, error) {
	parts := strings.Split(encoded, "$")
	if len(parts) != 6 || parts[0] != "" || parts[1] != "argon2id" || parts[2] != "v=19" {
		return false, ErrInvalidPasswordHash
	}

	var memory uint32
	var iterations uint32
	var parallelism uint8
	for _, param := range strings.Split(parts[3], ",") {
		key, value, ok := strings.Cut(param, "=")
		if !ok {
			return false, ErrInvalidPasswordHash
		}
		number, err := strconv.ParseUint(value, 10, 32)
		if err != nil {
			return false, ErrInvalidPasswordHash
		}
		switch key {
		case "m":
			memory = uint32(number)
		case "t":
			iterations = uint32(number)
		case "p":
			if number == 0 || number > 255 {
				return false, ErrInvalidPasswordHash
			}
			parallelism = uint8(number)
		default:
			return false, ErrInvalidPasswordHash
		}
	}
	if memory < 8*1024 || memory > 256*1024 || iterations < 1 || iterations > 10 || parallelism < 1 {
		return false, ErrInvalidPasswordHash
	}

	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil || len(salt) < 8 || len(salt) > 64 {
		return false, ErrInvalidPasswordHash
	}
	expected, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil || len(expected) < 16 || len(expected) > 64 {
		return false, ErrInvalidPasswordHash
	}

	actual := argon2.IDKey([]byte(password), salt, iterations, memory, parallelism, uint32(len(expected)))
	return subtle.ConstantTimeCompare(expected, actual) == 1, nil
}
