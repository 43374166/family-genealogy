GO ?= go
GOFLAGS ?= -buildvcs=false
DATABASE_URL ?= postgres://familytree:change-me@localhost:5432/familytree?sslmode=disable

.PHONY: run build fmt vet test migrate-up migrate-status migrate-down

run:
	GOFLAGS="$(GOFLAGS)" $(GO) run ./cmd/api

build:
	GOFLAGS="$(GOFLAGS)" $(GO) build -trimpath -o bin/api ./cmd/api
	GOFLAGS="$(GOFLAGS)" $(GO) build -trimpath -o bin/migrate ./cmd/migrate

fmt:
	gofmt -w cmd internal

vet:
	GOFLAGS="$(GOFLAGS)" $(GO) vet ./...

test:
	GOFLAGS="$(GOFLAGS)" $(GO) test -race ./...

migrate-up:
	DATABASE_URL="$(DATABASE_URL)" $(GO) run ./cmd/migrate up

migrate-status:
	DATABASE_URL="$(DATABASE_URL)" $(GO) run ./cmd/migrate status

migrate-down:
	DATABASE_URL="$(DATABASE_URL)" $(GO) run ./cmd/migrate down
