FROM golang:1.12-alpine AS builder

RUN apk add --no-cache git gcc libc-dev

# Create app directory
WORKDIR /go/src/github.com/tus/tusd

# Leverage docker layer caching on these large deps
RUN go get -d -v github.com/aws/aws-sdk-go
RUN go get -d -v google.golang.org/api
RUN go get -d -v net/http
RUN go get -d -v github.com/prometheus/client_golang/prometheus \
	github.com/prometheus/client_golang/prometheus/promhttp
RUN go get -d -v google.golang.org/grpc
# Copy in the git repo from the build context
COPY . /go/src/github.com/tus/tusd/

RUN go get -d -v ./... \
    && version="$(git tag -l --points-at HEAD)" \
    && commit=$(git log --format="%H" -n 1) \
    && GOOS=linux GOARCH=amd64 go build \
        -ldflags="-X github.com/tus/tusd/cmd/tusd/cli.VersionName=${version} -X github.com/tus/tusd/cmd/tusd/cli.GitCommit=${commit} -X 'github.com/tus/tusd/cmd/tusd/cli.BuildDate=$(date --utc)'" \
        -o "/go/bin/tusd" ./cmd/tusd/main.go

# start a new stage that copies in the binary built in the previous stage
FROM alpine:3.9

RUN apk add --no-cache ca-certificates \
    && addgroup -g 1000 tusd \
    && adduser -u 1000 -G tusd -s /bin/sh -D tusd \
    && mkdir -p /srv/tusd-hooks \
    && mkdir -p /srv/tusd-data \
    && chown tusd:tusd /srv/tusd-data

WORKDIR /srv/tusd-data
EXPOSE 1080
ENTRYPOINT ["tusd"]

COPY --from=builder /go/bin/tusd /usr/local/bin/tusd

CMD ["--hooks-dir","/srv/tusd-hooks"]

USER tusd
