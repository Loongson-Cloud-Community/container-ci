#!/bin/bash

set -Eeuo pipefail

version="$1"
major_ver=$(echo "$version" | cut -d. -f1)
minor_ver=$(echo "$version" | cut -d. -f2)
ver_num=$(( 10#$major_ver * 1000 + 10#$minor_ver ))

context="$version"

sed -i "s/ARG FLINK_VER=.*/ARG FLINK_VER=$version/" "$context/Dockerfile"

if [ "$ver_num" -lt 2002 ]; then
    cat << 'EOF' > /tmp/insert_block
ENV GOSU_VERSION=1.19
RUN set -ex; \
  wget -nv -O /usr/local/bin/gosu "https://github.com/loongarch64-releases/gosu/releases/download/${GOSU_VERSION}/gosu-loong64"; \
  chmod +x /usr/local/bin/gosu; \
  gosu nobody true
EOF
    sed -i '/ENV FLINK_TGZ_URL/e cat /tmp/insert_block' "$context/Dockerfile"
else
    sed -i '/ENTRYPOINT/i\
USER flink' "$context/Dockerfile"
fi
