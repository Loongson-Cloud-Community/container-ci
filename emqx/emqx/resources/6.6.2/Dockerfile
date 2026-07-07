FROM lcr.loongnix.cn/library/debian:14-slim

ARG RAW_VERSION=6.6.2
ARG EMQX_NAME=emqx-enterprise
ARG ID=debian
ARG VERSION_ID=13
ENV EMQX_VERSION=6.6.2
ENV LOONG64_SHA256=Not
ENV LC_ALL=C.UTF-8 LANG=C.UTF-8

RUN set -eu; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates procps curl adduser; \
    arch=$(dpkg --print-architecture); \
    if [ ${arch} = "loong64" ]; then sha256="$LOONG64_SHA256"; fi; \
    . /etc/os-release; \
    pkg="${EMQX_NAME}-${EMQX_VERSION}-${ID}${VERSION_ID}-loongarch64.tar.gz"; \
    curl -f -O -L https://github.com/loongarch64-releases/emqx/releases/download/${RAW_VERSION}/${pkg}; \
    echo "$sha256 *$pkg" | sha256sum -c; \
    mkdir /opt/emqx; \
    tar zxf $pkg -C /opt/emqx; \
    find /opt/emqx -name 'swagger*.js.map' -exec rm {} +; \
    ln -s /opt/emqx/bin/* /usr/local/bin/; \
    groupadd -r -g 1000 emqx; \
    useradd -r -m -u 1000 -g emqx emqx; \
    chown -R emqx:emqx /opt/emqx; \
    rm -f $pkg; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/emqx

USER emqx

VOLUME ["/opt/emqx/log", "/opt/emqx/data"]

# emqx will occupy these port:
# - 1883 port for MQTT
# - 8083 for WebSocket/HTTP
# - 8084 for WSS/HTTPS
# - 8883 port for MQTT(SSL)
# - 18083 for dashboard and API
# - 4370 default Erlang distribution port
# - 5369 for backplain gen_rpc
EXPOSE 1883 8083 8084 8883 18083 4370 5369

COPY docker-entrypoint.sh /usr/bin/

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

CMD ["/opt/emqx/bin/emqx", "foreground"]
