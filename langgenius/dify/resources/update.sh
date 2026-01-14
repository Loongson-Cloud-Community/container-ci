#!/bin/bash

set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

version="$1"
target_dir="$version"

# 创建目标目录
mkdir -p "$target_dir"

# Dockerfile
tar -xzf $version-src.tar.gz -C $target_dir --strip-components=1

sed -i '/^FROM node/c\FROM node:22-alpine-3.22 AS base' "$target_dir/web/Dockerfile" # web
cp api-dockerfile.template "$target_dir/api/Dockerfile" # api

echo "[✓] dockerfiles of web and api generated at $target_dir/web and $target_dir/api respectively"

