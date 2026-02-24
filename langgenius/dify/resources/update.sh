#!/bin/bash

set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

version="$1"
major_ver=$(echo "$version" | cut -d. -f1)
minor_ver=$(echo "$version" | cut -d. -f2)
target_dir="$version"

# 创建目标目录
mkdir -p "$target_dir"

# Dockerfile
tar -xzf $version-src.tar.gz -C $target_dir --strip-components=1

sed -i '/^FROM node/c\FROM node:22-alpine-3.22 AS base' "$target_dir/web/Dockerfile" # web
if [ "$major_ver" -gt 1 ] || ([ "$major_ver" -eq 1 ] && [ "$minor_ver" -ge 12 ]); then
    sed -i "/RUN pnpm build:docker/i \
RUN sed -i 's/next build/next build --webpack/' package.json \\
ENV NEXT_FORCE_WEBPACK=1" "$target_dir/web/Dockerfile"
fi

cp api-dockerfile.template "$target_dir/api/Dockerfile" # api

echo "[✓] dockerfiles of web and api generated at $target_dir/web and $target_dir/api respectively"

