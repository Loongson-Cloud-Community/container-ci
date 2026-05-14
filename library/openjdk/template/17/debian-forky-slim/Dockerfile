FROM lcr.loongnix.cn/library/debian:forky-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates wget tar gzip binutils fontconfig libfreetype6 p11-kit tzdata \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME /usr/local/openjdk-17.0.18.8
ENV PATH $JAVA_HOME/bin:$PATH
ENV LANG C.UTF-8

RUN set -eux; \
    wget --tries=5 --timeout=30 -O openjdk.tar.gz "https://ftp.loongnix.cn/Java/openjdk17/loongson17.17.26-fx-jdk17.0.18_8-linux-loongarch64-glibc2.34.tar.gz"; \
    if [ -n "3d296d6722bc81f556263ea2a78d45a0" ]; then \
        echo "3d296d6722bc81f556263ea2a78d45a0  openjdk.tar.gz" | md5sum -c -; \
    fi; \
    mkdir -p "$JAVA_HOME"; \
    tar -xzf openjdk.tar.gz -C "$JAVA_HOME" --strip-components=1; \
    rm openjdk.tar.gz; \
    mkdir -p "$JAVA_HOME/lib/security"; \
    { \
        echo '#!/bin/bash'; \
        echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$JAVA_HOME/lib/security/cacerts"'; \
    } > /etc/ca-certificates/update.d/docker-openjdk; \
    chmod +x /etc/ca-certificates/update.d/docker-openjdk; \
    /etc/ca-certificates/update.d/docker-openjdk; \
    find "$JAVA_HOME/lib" -name '*.so' -exec dirname {} \; | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
    ldconfig; \
    java -Xshare:dump || true; \
    javac -version; \
    java -version

CMD ["jshell"]
