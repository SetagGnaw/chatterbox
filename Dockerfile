# syntax=docker/dockerfile:1.18
FROM --platform=$BUILDPLATFORM golang:1.26.5-alpine AS build

ARG VERSION=dev
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src

COPY go.mod ./
COPY cmd ./cmd

# Tests run natively on the build platform; only the binary is
# cross-compiled for the target platform.
RUN CGO_ENABLED=0 go test ./... && \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build \
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

