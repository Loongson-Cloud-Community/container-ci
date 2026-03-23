#!/bin/bash

set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

ORG='langgenius'
PROJ='dify-sandbox'
version="$1"
major_ver=$(echo "$version" | cut -d. -f1)
minor_ver=$(echo "$version" | cut -d. -f2)
patch_ver=$(echo "$version" | cut -d. -f3)
ver_num=$(( 10#$major_ver * 1000000 + 10#$minor_ver * 1000 + 10#$patch_ver ))

# 创建目标目录
target_dir="$version"
mkdir -p "$target_dir"

# Dockerfile
dockerfile="$target_dir/Dockerfile"
if [ "$ver_num" -le 0002012 ]; then
    curl -sSL -o "$dockerfile" "https://raw.githubusercontent.com/$ORG/$PROJ/$version/docker/amd64/dockerfile"
    sed -i 's/-slim-bookworm/-sid/' $dockerfile
    sed -i 's/RUN echo.*/RUN true \\/' $dockerfile
    sed -i 's/-x64/-loong64/g' $dockerfile
    sed -i 's|npmmirror\.com/mirrors/node|github.com/loong64/node/releases/download|' $dockerfile
    sed -i 's/tar -xvf/tar --no-same-owner --no-same-permissions -xvf/' $dockerfile
    sed -i '/tar.*-xvf.*-C \/opt/s/\\$/|| true \\/' $dockerfile
else
    cp Dockerfile.template $dockerfile
fi

echo "[✓] Dockerfile generated at: $dockerfile"
