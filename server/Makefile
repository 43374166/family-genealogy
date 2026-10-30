GO ?= go
GOFLAGS ?= -buildvcs=false
DATABASE_DSN ?= familytree:change-me@tcp(127.0.0.1:3306)/familytree?parseTime=true&loc=UTC&charset=utf8mb4&collation=utf8mb4_0900_ai_ci

.PHONY: run build fmt vet test migrate-up migrate-status migrate-down

run:
	GOFLAGS="$(GOFLAGS)" DATABASE_DSN="$(DATABASE_DSN)" $(GO) run ./cmd/api

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
	DATABASE_DSN="$(DATABASE_DSN)" $(GO) run ./cmd/migrate up

migrate-status:
	DATABASE_DSN="$(DATABASE_DSN)" $(GO) run ./cmd/migrate status

migrate-down:
	DATABASE_DSN="$(DATABASE_DSN)" $(GO) run ./cmd/migrate down
