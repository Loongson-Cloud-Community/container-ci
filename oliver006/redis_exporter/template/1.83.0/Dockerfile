#
# download redis_exporter loong64 release binary
#
FROM lcr.loongnix.cn/library/alpine:3.24 AS builder
WORKDIR /

RUN apk --no-cache add ca-certificates wget

RUN wget -q https://github.com/loongarch64-releases/redis_exporter/releases/download/v1.83.0/redis_exporter-v1.83.0.linux-loong64.tar.gz && \
    tar xf redis_exporter-v1.83.0.linux-loong64.tar.gz && \
    mv /redis_exporter-v1.83.0.linux-loong64/redis_exporter /redis_exporter && \
    chmod +x /redis_exporter

#
# Alpine release container
#
FROM lcr.loongnix.cn/library/alpine:3.24 AS alpine

COPY --from=builder /redis_exporter /redis_exporter
COPY --from=builder /etc/ssl/certs /etc/ssl/certs

# Run as non-root user for secure environments
USER 59000:59000

EXPOSE     9121
ENTRYPOINT [ "/redis_exporter" ]
