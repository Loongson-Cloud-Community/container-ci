#!/bin/bash

set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

readonly ORG='langgenius'
readonly PROJ='dify-plugin-daemon'
version="$1"
target_dir="$version"

# 创建目标目录
mkdir -p "$target_dir"

# 准备构建环境
wget -O $version-src.tar.gz --quiet --show-progress https://github.com/$ORG/$PROJ/archive/refs/tags/$version.tar.gz
tar -xzf $version-src.tar.gz -C $target_dir --strip-components=1
pushd $target_dir/docker
cp "local.dockerfile" ..
sed -i '/^FROM ubuntu/c\FROM debian:forky' "../local.dockerfile"
sed -i '/python3 -m pip install uv/s/$/==0.9.9 -i https:\/\/lpypi.loongnix.cn\/loongson\/pypi\/+simple/' "../local.dockerfile"
sed -i '/uv pip install --system dify_plugin/s/$/ -i https:\/\/lpypi.loongnix.cn\/loongson\/pypi\/+simple/' "../local.dockerfile"

cp "serverless.dockerfile" ..
sed -i '/^FROM alpine/c\FROM alpine:3.23' "../serverless.dockerfile"
popd

rm -f "$version-src.tar.gz"

echo "[✓] local.dockerfile & serverless.dockerfile generated at: $target_dir"
