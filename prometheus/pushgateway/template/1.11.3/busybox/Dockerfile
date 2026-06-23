FROM lcr.loongnix.cn/library/alpine:3.23.4 as builder

WORKDIR /

RUN apk update && apk add wget tar


RUN wget https://github.com/loongarch64-releases/pushgateway/releases/download/1.11.3/pushgateway-1.11.3.linux-loong64.tar.gz && \
    mkdir pushgateway && \
    tar xf pushgateway-1.11.3.linux-loong64.tar.gz -C pushgateway --strip-components=1

ARG ARCH="loong64"
ARG OS="linux"
FROM lcr.loongnix.cn/prometheus/busybox:glibc-1.37.0
LABEL maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"

ARG ARCH="loong64"
ARG OS="loong64"
COPY --from=builder --chown=nobody:nobody /pushgateway/pushgateway /bin/pushgateway

EXPOSE 9091
WORKDIR /pushgateway
RUN chown nobody:nobody /pushgateway && chmod g+w /pushgateway

USER 65534

ENTRYPOINT [ "/bin/pushgateway" ]
