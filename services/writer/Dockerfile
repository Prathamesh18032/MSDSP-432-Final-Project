FROM --platform=$BUILDPLATFORM golang:1.23-bookworm AS build

ARG TARGETOS=linux
ARG TARGETARCH=amd64

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY internal ./internal
COPY services/writer ./services/writer

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/export-cold \
    ./services/writer/cmd/export-cold

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/consume-pubsub \
    ./services/writer/cmd/consume-pubsub

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/backup-timescale \
    ./services/writer/cmd/backup-timescale

FROM alpine:3.20

LABEL org.opencontainers.image.title="smartcity-writer" \
      org.opencontainers.image.description="Smart City cold-storage export writer" \
      org.opencontainers.image.source="https://github.com/Prathamesh18032/MSDSP-432-Final-Project"

RUN apk add --no-cache ca-certificates postgresql-client \
    && addgroup -S smartcity \
    && adduser -S -G smartcity -u 10001 smartcity

COPY --from=build /out/export-cold /usr/local/bin/export-cold
COPY --from=build /out/consume-pubsub /usr/local/bin/consume-pubsub
COPY --from=build /out/backup-timescale /usr/local/bin/backup-timescale

USER smartcity

ENTRYPOINT ["/usr/local/bin/export-cold"]
