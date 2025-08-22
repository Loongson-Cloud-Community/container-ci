FROM golang:1.24-trixie AS builder-mc
ENV MC_VERSION RELEASE.2024-07-26T13-08-44Z

WORKDIR /opt
RUN set -ex \
    && git clone -b ${MC_VERSION} --depth=1 https://github.com/minio/mc.git

WORKDIR /opt/mc
RUN set -ex \
    && MC_RELEASE="RELEASE" make build \
    && ./mc --version


FROM golang:1.22-alpine as build

LABEL maintainer="MinIO Inc <dev@min.io>"

ENV GOPATH /go
ENV CGO_ENABLED 0


RUN apk add -U --no-cache ca-certificates
RUN apk add -U curl
RUN curl -s -q https://raw.githubusercontent.com/minio/mc/master/LICENSE -o /go/LICENSE
RUN curl -s -q https://raw.githubusercontent.com/minio/mc/master/CREDITS -o /go/CREDITS
#RUN go install -v -ldflags "$(go run buildscripts/gen-ldflags.go)" "github.com/minio/mc@latest"

FROM scratch

COPY --from=builder-mc /opt/mc/mc /usr/bin/mc
COPY --from=build /go/CREDITS /licenses/CREDITS
COPY --from=build /go/LICENSE /licenses/LICENSE
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENTRYPOINT ["mc"]
