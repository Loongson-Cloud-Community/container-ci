#!/bin/bash

set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

version="$1"
target_dir="$version"
template_file="dify-sandbox-$version/docker/amd64/dockerfile"

# 创建目标目录
mkdir -p "$target_dir"

# 复制源码中amd64的dockerfile,改为可用版本
dockerfile="$target_dir/Dockerfile"
cp $template_file $target_dir/Dockerfile
sed -i 's/-slim-bookworm/-sid/g' $dockerfile
sed -i 's/echo "deb http:\/\/deb\.debian\.org\/debian testing main" > \/etc\/apt\/sources\.list/true/g' $dockerfile
sed -i 's/-x64/-loong64/g' $dockerfile
sed -i 's/npmmirror\.com\/mirrors\/node/github.com\/loong64\/node\/releases\/download/' $dockerfile
sed -i 's/tar -xvf/tar --no-same-owner --no-same-permissions -xvf/' $dockerfile
sed -i '/tar.*-xvf.*-C \/opt/s/\\$/|| true \\/' $dockerfile

echo "[✓] Dockerfile generated at: $dockerfile"
