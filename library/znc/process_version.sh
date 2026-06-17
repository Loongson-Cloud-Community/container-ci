#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="znc"
REPO_URL="https://github.com/znc/znc.git"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

log "Cloning ZNC version $VERSION..."
git clone --depth 1 --branch "znc-$VERSION" "$REPO_URL" "$TEMP_DIR" || {
    log "Depth clone failed, cloning full..."
    git clone "$REPO_URL" "$TEMP_DIR"
    cd "$TEMP_DIR"
    git checkout "znc-$VERSION"
    cd -
}

cd "$TEMP_DIR"
log "Initializing submodules..."
git submodule update --init --recursive

log "Modifying Dockerfile base images..."
sed -i 's|^FROM alpine:.*$|FROM lcr.loongnix.cn/library/alpine:3.23|g' docker/slim/Dockerfile
sed -i 's|^FROM znc:slim$|FROM lcr.loongnix.cn/library/znc:slim|g' docker/full/Dockerfile

IMAGE_NAME="${REGISTRY}/${ORG}/${PROJ}"
MAJOR_MINOR="${VERSION%.*}"
MAJOR="${VERSION%%.*}"

# 构建 slim
log "Building ${IMAGE_NAME}:${VERSION}-slim"
docker build --network host -t "${IMAGE_NAME}:${VERSION}-slim" -f docker/slim/Dockerfile docker/slim
docker push "${IMAGE_NAME}:${VERSION}-slim"
for alias in "${VERSION}-slim" "${MAJOR_MINOR}-slim" "slim"; do
    docker tag "${IMAGE_NAME}:${VERSION}-slim" "${IMAGE_NAME}:${alias}"
    docker push "${IMAGE_NAME}:${alias}"
    log "Pushed alias: ${alias}"
done

# 构建 full
log "Building ${IMAGE_NAME}:${VERSION}"
docker build --network host -t "${IMAGE_NAME}:${VERSION}" -f docker/full/Dockerfile docker/full
docker push "${IMAGE_NAME}:${VERSION}"
for alias in "$VERSION" "$MAJOR_MINOR" "$MAJOR" "latest"; do
    docker tag "${IMAGE_NAME}:${VERSION}" "${IMAGE_NAME}:${alias}"
    docker push "${IMAGE_NAME}:${alias}"
    log "Pushed alias: ${alias}"
done

log "Completed processing version $VERSION"
