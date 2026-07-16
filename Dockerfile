# syntax=docker/dockerfile:1.18
FROM golang:1.26.5-alpine AS build

ARG VERSION=dev
WORKDIR /src

COPY go.mod ./
COPY cmd ./cmd

RUN CGO_ENABLED=0 go test ./... && \
    CGO_ENABLED=0 go build \
      -trimpath \
      -ldflags="-s -w -X main.version=${VERSION}" \
      -o /out/server \
      ./cmd/server

FROM scratch

ARG SOURCE=""
ARG REVISION=""
LABEL org.opencontainers.image.source=$SOURCE \
      org.opencontainers.image.revision=$REVISION

COPY --from=build /out/server /server

USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/server"]

