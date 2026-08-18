#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="adminer"
VERSIONS_JSON="${SCRIPT_DIR}/versions.json"

source "${SCRIPT_DIR}/lib.sh"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <major_version>"
    exit 1
fi

MAJOR="$1"

if [ ! -f "$VERSIONS_JSON" ]; then
    die "$VERSIONS_JSON not found. Run fetch_versions.sh first."
fi

# 读取完整版本
FULL_VERSION=$(jq -r ".\"$MAJOR\"" "$VERSIONS_JSON")
if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
    die "Cannot find version for $MAJOR in $VERSIONS_JSON"
fi

log "Processing $MAJOR ($FULL_VERSION)"

# 替换基础镜像
fix_base_image() {
    local dockerfile="$SCRIPT_DIR/$MAJOR/Dockerfile"
    if [ ! -f "$dockerfile" ]; then
        die "Dockerfile not found: $dockerfile"
    fi
    log "Replacing base image in $dockerfile"
    sed -i 's|^FROM php:.*-alpine|FROM lcr.loongnix.cn/library/php:8.4-alpine|' "$dockerfile"
    log "Base image replaced"
}

# 构建镜像
build_image() {
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local build_dir="$SCRIPT_DIR/$MAJOR"
    local tag="$MAJOR"
    local full_tag="$FULL_VERSION"

    if [ ! -d "$build_dir" ]; then
        die "Build directory $build_dir does not exist"
    fi

    log "Building ${image_name}:${tag} from $build_dir"
    docker build --network host -t "${image_name}:${tag}" -t "${image_name}:${full_tag}" -f "$build_dir/Dockerfile" "$build_dir" || die "Build failed"
    log "Build completed for ${image_name}:${tag} and ${image_name}:${full_tag}"
}

# 推送镜像
push_image() {
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local tag="$1"

    if ! docker image inspect "${image_name}:${tag}" >/dev/null 2>&1; then
        log "WARNING: Image ${image_name}:${tag} not found, skipping push"
        return 0
    fi
    log "Pushing ${image_name}:${tag}"
    docker push "${image_name}:${tag}" || die "Push failed for ${tag}"
    log "Push completed for ${image_name}:${tag}"
}

fix_base_image
build_image

# 推送（本地测试时可注释）
 push_image "$MAJOR"
 push_image "$FULL_VERSION"

log "Completed $MAJOR ($FULL_VERSION)"
