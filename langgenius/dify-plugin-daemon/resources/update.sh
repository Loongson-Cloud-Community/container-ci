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
sed -i '/EXTERNALLY-MANAGED/d' "../local.dockerfile"
sed -i '/update-alternatives/d' "../local.dockerfile"
sed -i 's/python3.12-dev//' "../local.dockerfile"
sed -i 's/python3.12-venv//' "../local.dockerfile"
sed -i 's/python3.12//' "../local.dockerfile"
sed -i 's/python3-pip//' "../local.dockerfile"
sed -i '/python3 -m pip install uv/s/$/==0.9.9 -i https:\/\/lpypi.loongnix.cn\/loongson\/pypi\/+simple/' "../local.dockerfile"
sed -i '/python3 -m pip install/a\
ln -sf /usr/bin/uv /usr/local/bin/uv' "../local.dockerfile"
sed -i '/uv pip install --system dify_plugin/s/$/ -i https:\/\/lpypi.loongnix.cn\/loongson\/pypi\/+simple/' "../local.dockerfile"
sed -i '/rm -rf/a\
cd /tmp && \\\
    wget https://www.python.org/ftp/python/3.12.10/Python-3.12.10.tgz && \\\
    tar -xzf Python-3.12.10.tgz && \\\
    cd Python-3.12.10 && \\\
    ./configure --enable-optimizations --prefix=/usr --with-ensurepip=install && \\\
    make -j$(nproc) && \\\
    make altinstall\
rm -rf /tmp/*\
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1\
update-alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.12 1;\
' "../local.dockerfile"
sed -i '/install -y/a\
    wget zlib1g-dev libffi-dev libssl-dev libbz2-dev \\\
    libreadline-dev libsqlite3-dev libncursesw5-dev \\\
    xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev \\\
    liblzma-dev libexpat1-dev \\' "../local.dockerfile"

cp "serverless.dockerfile" ..
sed -i '/^FROM alpine/c\FROM alpine:3.23' "../serverless.dockerfile"
popd

rm -f "$version-src.tar.gz"

echo "[✓] local.dockerfile & serverless.dockerfile generated at: $target_dir"
