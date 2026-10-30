FROM golang:1.25.3-alpine AS build

ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_TIME=unknown

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build \
      -trimpath -buildvcs=false \
      -ldflags="-s -w \
        -X github.com/43374166/family-genealogy/server/internal/buildinfo.Version=${VERSION} \
        -X github.com/43374166/family-genealogy/server/internal/buildinfo.Commit=${COMMIT} \
        -X github.com/43374166/family-genealogy/server/internal/buildinfo.BuildTime=${BUILD_TIME}" \
      -o /out/api ./cmd/api && \
    CGO_ENABLED=0 GOOS=linux go build \
      -trimpath -buildvcs=false \
      -o /out/migrate ./cmd/migrate

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/api /api
COPY --from=build /out/migrate /migrate

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/api"]
