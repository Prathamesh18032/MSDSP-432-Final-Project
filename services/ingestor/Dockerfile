FROM golang:1.23-bookworm AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY internal ./internal
COPY services/ingestor ./services/ingestor

RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/poll-multisource \
    ./services/ingestor/cmd/poll-multisource

FROM alpine:3.20

LABEL org.opencontainers.image.title="smartcity-ingestor" \
      org.opencontainers.image.description="Smart City multi-source sensor ingestor" \
      org.opencontainers.image.source="https://github.com/Prathamesh18032/MSDSP-432-Final-Project"

RUN apk add --no-cache ca-certificates \
    && addgroup -S smartcity \
    && adduser -S -G smartcity -u 10001 smartcity

COPY --from=build /out/poll-multisource /usr/local/bin/poll-multisource

USER smartcity

ENTRYPOINT ["/usr/local/bin/poll-multisource"]
