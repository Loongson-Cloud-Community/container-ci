FROM lcr.loongnix.cn/library/debian:trixie-slim

RUN if grep 'debian-ports' /etc/apt/sources.list.d/debian.sources; then \
        rm -rf /etc/apt/sources.list.d/debian.sources; \
        echo 'deb [trusted=yes] http://mirrors.aliyun.com/debian-ports sid main' > /etc/apt/sources.list.d/debian-ports.list; \
    fi;

RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

ENV NODE_VERSION=24.7.0

RUN ARCH= OPENSSL_ARCH= && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
      amd64) ARCH='x64' OPENSSL_ARCH='linux-x86_64';; \
      ppc64el) ARCH='ppc64le' OPENSSL_ARCH='linux-ppc64le';; \
      s390x) ARCH='s390x' OPENSSL_ARCH='linux*-s390x';; \
      arm64) ARCH='arm64' OPENSSL_ARCH='linux-aarch64';; \
      loong64) ARCH='loong64' OPENSSL_ARCH='linux-loongarch64';; \
      armhf) ARCH='armv7l' OPENSSL_ARCH='linux-armv4';; \
      i386) ARCH='x86' OPENSSL_ARCH='linux-elf';; \
      *) echo "unsupported architecture"; exit 1 ;; \
    esac \
    && set -ex \
    # libatomic1 for arm
    && apt-get update && apt-get install -y ca-certificates curl wget xz-utils libatomic1 --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    # gpg keys listed at https://github.com/nodejs/node#release-keys
    && curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
    && curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/SHASUMS256.txt" \
    && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt \
    # Remove unused OpenSSL headers to save ~34MB. See this NodeJS issue: https://github.com/nodejs/node/issues/46451
    && find /usr/local/include/node/openssl/archs -mindepth 1 -maxdepth 1 ! -name "$OPENSSL_ARCH" -exec rm -rf {} \; \
    && apt-mark auto '.*' > /dev/null \
    && find /usr/local -type f -executable -exec ldd '{}' ';' \
      | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
      | sort -u \
      | xargs -r dpkg-query --search \
      | cut -d: -f1 \
      | sort -u \
      | xargs -r apt-mark manual \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
    # smoke tests
    && node --version \
    && npm --version \
    && rm -rf /tmp/*

ENV YARN_VERSION=1.22.22

RUN set -ex \
  && apt-get update && apt-get install -y ca-certificates curl wget --no-install-recommends \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz \
  && apt-mark auto '.*' > /dev/null \
  && { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; } \
  && find /usr/local -type f -executable -exec ldd '{}' ';' \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  # smoke test
  && yarn --version \
  && rm -rf /tmp/*

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD [ "node" ]
