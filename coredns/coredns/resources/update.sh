#!/bin/bash

set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

readonly ORG='coredns'
readonly PROJ='coredns'
version="$1"
target_dir="$version"

# 创建目标目录
mkdir -p "$target_dir"

# 准备构建环境
wget -O $version-src.tar.gz --quiet --show-progress "https://github.com/$ORG/$PROJ/archive/refs/tags/v$version.tar.gz"
tar -xzf $version-src.tar.gz -C $target_dir --strip-components=1

sed -i "s/^ARG DEBIAN_IMAGE=.*/ARG DEBIAN_IMAGE=debian:14-slim/" "$target_dir/Dockerfile"
sed -i "s/^ARG BASE=.*/ARG BASE=debian:14-slim/" "$target_dir/Dockerfile"
sed -i "/COPY coredns \/coredns/a \
RUN chmod +x /coredns" "$target_dir/Dockerfile"
sed -i "/USER nonroot:nonroot/i \
RUN groupadd --gid 65532 nonroot && \\\
    useradd --uid 65532 --gid 65532 --no-create-home --shell /usr/sbin/nologin nonroot" "$target_dir/Dockerfile"

echo "[✓] dockerfile generated at: $target_dir"
