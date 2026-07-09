#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="traefik"
REPO_URL="https://github.com/traefik/traefik.git"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
TAG="v$VERSION"
PROJECT_ROOT="$PWD"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

log "Cloning Traefik repository (tag $TAG)..."
git clone --depth 1 --branch "$TAG" "$REPO_URL" "$TEMP_DIR"

cd "$TEMP_DIR"

# 应用补丁
log "Applying patches from $PROJECT_ROOT/patches/..."
PATCHES_DIR="$PROJECT_ROOT/patches"
if [ -d "$PATCHES_DIR" ]; then
    # 按顺序应用所有 .patch 文件
    for patch_file in "$PATCHES_DIR"/*.patch; do
        if [ -f "$patch_file" ]; then
            log "Applying $patch_file"
            patch -p1 < "$patch_file" || {
                log "ERROR: Failed to apply $patch_file"
                exit 1
            }
        fi
    done
else
    log "WARNING: $PATCHES_DIR not found, skipping patches"
fi

# 修改 Dockerfile 基础镜像
log "Modifying Dockerfile base image..."
sed -i 's|^FROM alpine:.*$|FROM lcr.loongnix.cn/library/alpine:3.24|' Dockerfile

# 移除 syntax 指令（不兼容 loong64）
sed -i '/^# syntax=docker\/dockerfile/d' Dockerfile

# 编译 LoongArch 二进制
log "Building Traefik binary for loong64 using make..."
make binary-linux-loong64

# 准备 template 目录
log "Copying build context to project template directory..."
PROJECT_TEMPLATE="$PROJECT_ROOT/template"
rm -rf "$PROJECT_TEMPLATE"
mkdir -p "$PROJECT_TEMPLATE"

cp Dockerfile "$PROJECT_TEMPLATE/"
mkdir -p "$PROJECT_TEMPLATE/dist/linux/loong64"
cp dist/linux/loong64/traefik "$PROJECT_TEMPLATE/dist/linux/loong64/"

IMAGE_NAME="${REGISTRY}/${ORG}/${PROJ}"
MAJOR_MINOR="${VERSION%.*}"
MAJOR="${VERSION%%.*}"

# 构建镜像
log "Building ${IMAGE_NAME}:${VERSION}"
docker build --network host -t "${IMAGE_NAME}:${VERSION}" "$PROJECT_TEMPLATE"
docker push "${IMAGE_NAME}:${VERSION}"

for alias in "$VERSION" "$MAJOR_MINOR" "$MAJOR" "latest"; do
    docker tag "${IMAGE_NAME}:${VERSION}" "${IMAGE_NAME}:${alias}"
    docker push "${IMAGE_NAME}:${alias}"
    log "Pushed alias: ${alias}"
done

log "Completed processing version $VERSION"
