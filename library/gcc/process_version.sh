#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="gcc"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
DOCKERFILE="template/$VERSION/Dockerfile"
if [ ! -f "$DOCKERFILE" ]; then
    log "ERROR: $DOCKERFILE not found"
    exit 1
fi

# 从 Dockerfile 中提取 GCC_VERSION
GCC_VERSION=$(grep -E '^ENV GCC_VERSION' "$DOCKERFILE" | awk '{print $3}')
if [ -z "$GCC_VERSION" ]; then
    log "ERROR: Cannot find GCC_VERSION in $DOCKERFILE"
    exit 1
fi

IMAGE_NAME="${REGISTRY}/${ORG}/${PROJ}"
TAG="${VERSION}"
FULL_TAG="${GCC_VERSION}"

log "Building ${IMAGE_NAME}:${TAG} and ${IMAGE_NAME}:${FULL_TAG}"
docker build --network host -t "${IMAGE_NAME}:${TAG}" -f "$DOCKERFILE" template
docker tag "${IMAGE_NAME}:${TAG}" "${IMAGE_NAME}:${FULL_TAG}"

docker push "${IMAGE_NAME}:${TAG}"
docker push "${IMAGE_NAME}:${FULL_TAG}"

log "Pushed ${IMAGE_NAME}:${TAG} and ${IMAGE_NAME}:${FULL_TAG}"
