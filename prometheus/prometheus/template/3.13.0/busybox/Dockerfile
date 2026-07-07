FROM lcr.loongnix.cn/library/alpine:3.23.4 as builder

WORKDIR /

RUN apk update && apk add wget tar


RUN wget https://github.com/loongarch64-releases/prometheus/releases/download/3.13.0/prometheus-3.13.0.linux-loong64.tar.gz && \
    mkdir prometheus && \
    tar xf prometheus-3.13.0.linux-loong64.tar.gz -C prometheus --strip-components=1

ARG ARCH="loong64"
ARG OS="linux"
FROM lcr.loongnix.cn/prometheus/busybox:glibc-1.37.0
LABEL maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"
LABEL org.opencontainers.image.authors="The Prometheus Authors" \
      org.opencontainers.image.vendor="Prometheus" \
      org.opencontainers.image.title="Prometheus" \
      org.opencontainers.image.description="The Prometheus monitoring system and time series database" \
      org.opencontainers.image.source="https://github.com/prometheus/prometheus" \
      org.opencontainers.image.url="https://github.com/prometheus/prometheus" \
      org.opencontainers.image.documentation="https://prometheus.io/docs" \
      org.opencontainers.image.licenses="Apache License 2.0" \
      io.prometheus.image.variant="busybox"

ARG ARCH="loong64"
ARG OS="linux"
COPY --from=builder prometheus/prometheus        /bin/prometheus
COPY --from=builder prometheus/promtool          /bin/promtool
COPY --from=builder prometheus/prometheus.yml  /etc/prometheus/prometheus.yml
COPY --from=builder prometheus/LICENSE                                /LICENSE
COPY --from=builder prometheus/NOTICE                                 /NOTICE

WORKDIR /prometheus
RUN chown -R nobody:nobody /etc/prometheus /prometheus && chmod g+w /prometheus

USER       nobody
EXPOSE     9090
VOLUME     [ "/prometheus" ]
ENTRYPOINT [ "/bin/prometheus" ]
CMD        [ "--config.file=/etc/prometheus/prometheus.yml", \
             "--storage.tsdb.path=/prometheus" ]
