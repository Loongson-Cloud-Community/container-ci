FROM lcr.loongnix.cn/library/alpine:3.23.4 as builder

WORKDIR /

RUN apk update && \
    apk add wget

RUN wget -q https://github.com/loongarch64-releases/node_exporter/releases/download/1.11.1/node_exporter-1.11.1.linux-loong64.tar.gz && \
    tar xf node_exporter-1.11.1.linux-loong64.tar.gz && \
    chmod +x /node_exporter-1.11.1.linux-loong64/node_exporter

FROM lcr.loongnix.cn/prometheus/busybox@sha256:d3544d02a3ca457941691389d31d05c80f2cd1547b7f0f0d6147d0850c4d65e3
LABEL maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"
LABEL org.opencontainers.image.authors="The Prometheus Authors"
LABEL org.opencontainers.image.vendor="Prometheus"
LABEL org.opencontainers.image.title="node_exporter"
LABEL org.opencontainers.image.description="Prometheus exporter for hardware and OS metrics exposed by *NIX kernels"
LABEL org.opencontainers.image.source="https://github.com/prometheus/node_exporter"
LABEL org.opencontainers.image.url="https://github.com/prometheus/node_exporter"
LABEL org.opencontainers.image.documentation="https://github.com/prometheus/node_exporter"
LABEL org.opencontainers.image.licenses="Apache License 2.0"
LABEL io.prometheus.image.variant="busybox"

ARG ARCH="loong64"
ARG OS="linux"
COPY --from=builder /node_exporter-1.11.1.linux-loong64/node_exporter /bin/node_exporter

EXPOSE      9100
USER        nobody
ENTRYPOINT  [ "/bin/node_exporter" ]
