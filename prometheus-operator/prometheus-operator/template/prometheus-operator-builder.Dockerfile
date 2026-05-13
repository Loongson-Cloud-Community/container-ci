ARG ARCH=loong64
ARG OS=linux
ARG GOLANG_BUILDER=1.26

FROM lcr.loongnix.cn/library/debian:unstable AS builder

RUN apt update && apt install -y golang git build-essential

WORKDIR /workspace

COPY . .

RUN go env -w GOPROXY=https://goproxy.cn,direct
# Download Go dependencies to reuse the Go cache in subsequent builds.
RUN go mod download -x && go mod verify

# Build
ARG GOARCH=loong64
ENV GOARCH=${GOARCH}
RUN make operator

FROM lcr.loongnix.cn/prometheus/busybox:glibc-1.37.0

COPY --from=builder workspace/operator /bin/operator

# On busybox 'nobody' has uid `65534'
USER 65534

LABEL org.opencontainers.image.source="https://github.com/prometheus-operator/prometheus-operator" \
    org.opencontainers.image.url="https://prometheus-operator.dev/" \
    org.opencontainers.image.documentation="https://prometheus-operator.dev/" \
    org.opencontainers.image.licenses="Apache-2.0"

ENTRYPOINT ["/bin/operator"]
