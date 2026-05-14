FROM openanolis/anolisos:23.4

RUN set -eux; \
    dnf install -y \
	tzdata \
        ca-certificates \
        wget \
        tar \
        gzip \
        binutils \
        fontconfig \
        freetype \
        p11-kit \
    && dnf clean all

ENV JAVA_HOME /usr/local/openjdk-8u482-b08
ENV PATH $JAVA_HOME/bin:$PATH
ENV LANG C.UTF-8

RUN set -eux; \
    wget -O openjdk.tar.gz "https://ftp.loongnix.cn/Java/openjdk8/loongson8.1.26-fx-jdk8u482b08-linux-loongarch64-glibc2.34.tar.gz"; \
    mkdir -p "$JAVA_HOME"; \
    tar -xzf openjdk.tar.gz -C "$JAVA_HOME" --strip-components=1; \
    rm openjdk.tar.gz; \
    mkdir -p "$JAVA_HOME/lib/security"; \
    # For RPM-based distros, ensure CA certificates are extracted
    if command -v update-ca-trust >/dev/null; then \
        update-ca-trust extract; \
    fi; \
    find "$JAVA_HOME/lib" -name '*.so' -exec dirname {} \; | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
    ldconfig; \
    java -Xshare:dump || true; \
    javac -version; \
    java -version

CMD ["jshell"]
