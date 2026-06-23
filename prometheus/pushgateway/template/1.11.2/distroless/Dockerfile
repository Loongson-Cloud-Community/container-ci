FROM lcr.loongnix.cn/library/alpine:3.23.4 as builder

WORKDIR /

RUN apk update && apk add wget tar


RUN wget https://github.com/loongarch64-releases/pushgateway/releases/download/1.11.2/pushgateway-1.11.2.linux-loong64.tar.gz && \
    mkdir pushgateway && \
    tar xf pushgateway-1.11.2.linux-loong64.tar.gz -C pushgateway --strip-components=1

ARG ARCH="loong64"
ARG OS="linux"

FROM lcr.loongnix.cn/distroless/static-debian12:latest

LABEL maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"

ARG ARCH="loong64"
ARG OS="linux"

LABEL org.opencontainers.image.authors="The Prometheus Authors"
LABEL org.opencontainers.image.vendor="Prometheus"
LABEL org.opencontainers.image.title="Pushgateway"
LABEL org.opencontainers.image.description="Push acceptor allowing ephemeral and batch jobs to expose their metrics to Prometheus."
LABEL org.opencontainers.image.source="https://github.com/prometheus/pushgateway"
LABEL org.opencontainers.image.url="https://github.com/prometheus/pushgateway"
LABEL org.opencontainers.image.documentation="https://github.com/prometheus/pushgateway"
LABEL org.opencontainers.image.licenses="Apache License 2.0"
LABEL io.prometheus.image.variant="distroless"

COPY --from=builder --chown=nobody:nobody /pushgateway/LICENSE /
COPY --from=builder --chown=nobody:nobody /pushgateway/NOTICE /
COPY --from=builder --chown=nobody:nobody /pushgateway/pushgateway /bin/pushgateway

EXPOSE 9091
WORKDIR /pushgateway

ENTRYPOINT [ "/bin/pushgateway" ]
