# syntax=docker/dockerfile:1
FROM golang:1.25-alpine AS builder

ARG VERSION=unknown

# copy project
COPY . /app

# set working directory
WORKDIR /app

# using goproxy if you have network issues
# ENV GOPROXY=https://goproxy.cn,direct

# build
RUN go build \
    -ldflags "\
    -X 'github.com/langgenius/dify-plugin-daemon/pkg/manifest.VersionX=${VERSION}' \
    -X 'github.com/langgenius/dify-plugin-daemon/pkg/manifest.BuildTimeX=$(date -u +%Y-%m-%dT%H:%M:%S%z)'" \
    -o /app/main cmd/server/main.go

# copy entrypoint.sh
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

FROM debian:forky

WORKDIR /app

# check build args
ARG PLATFORM=local

# Install  if PLATFORM is local
RUN <<EOF bash

set -ex
set -o pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND"' ERR

apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y curl  \
    wget zlib1g-dev libffi-dev libssl-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncursesw5-dev \
    xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev \
    liblzma-dev libexpat1-dev \
       ffmpeg \
    build-essential git \
    cmake pkg-config \
    libcairo2-dev libjpeg-dev libgif-dev

apt-get clean
rm -rf /var/lib/apt/lists/*
cd /tmp && \
    wget https://www.python.org/ftp/python/3.12.10/Python-3.12.10.tgz && \
    tar -xzf Python-3.12.10.tgz && \
    cd Python-3.12.10 && \
    ./configure --enable-optimizations --prefix=/usr --with-ensurepip=install && \
    make -j$(nproc) && \
    make altinstall
rm -rf /tmp/*
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
update-alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.12 1;

EOF

# preload tiktoken
ENV TIKTOKEN_CACHE_DIR=/app/.tiktoken

# Install dify_plugin to speedup the environment setup, test uv and preload tiktoken
RUN <<EOF bash

set -ex
set -o pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND"' ERR

python3 -m pip install uv==0.9.9 -i https://lpypi.loongnix.cn/loongson/pypi/+simple
ln -sf /usr/bin/uv /usr/local/bin/uv
uv pip install --system dify_plugin -i https://lpypi.loongnix.cn/loongson/pypi/+simple

python3 -c "from uv._find_uv import find_uv_bin;print(find_uv_bin());"

python3 -c "import tiktoken; encodings = ['o200k_base', 'cl100k_base', 'p50k_base', 'r50k_base', 'p50k_edit', 'gpt2']; [tiktoken.get_encoding(encoding).special_tokens_set for encoding in encodings]"
EOF

ENV UV_PATH=/usr/local/bin/uv
ENV PLATFORM=$PLATFORM
ENV GIN_MODE=release

COPY --from=builder /app/main /app/entrypoint.sh /app/
COPY --from=builder /app/uv.toml /etc/uv/uv.toml

# run the server, using sh as the entrypoint to avoid process being the root process
# and using bash to recycle resources
CMD ["/bin/bash", "-c", "/app/entrypoint.sh"]
