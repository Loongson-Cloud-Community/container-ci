#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="api-firewall"
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

FULL_VERSION=$(jq -r ".\"$MAJOR\"" "$VERSIONS_JSON")
if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
    die "Cannot find version for $MAJOR in $VERSIONS_JSON"
fi

log "Processing $MAJOR ($FULL_VERSION)"

# 准备源码到 template/src
prepare_source() {
    local version="$1"
    local repo_url="https://github.com/wallarm/api-firewall.git"
    local src_dir="${TEMPLATE_DIR}/src"

    rm -rf "$src_dir"
    mkdir -p "$src_dir"

    log "Cloning source code for tag v${version} into template/src..."
    cd "$TEMPLATE_DIR"
    git clone --depth 1 --branch "v${version}" "$repo_url" src || {
        log "git clone failed, trying wget..."
        rm -rf src
        mkdir -p src
        wget -qO- "https://github.com/wallarm/api-firewall/archive/refs/tags/v${version}.tar.gz" | tar -xz -C src --strip-components=1
    }

    if [ ! -f "$src_dir/Dockerfile" ]; then
        die "Failed to download source code for v${version}"
    fi

    cd "$SCRIPT_DIR"
    log "Source code prepared in ${src_dir}"
}

# 修改 Dockerfile 为基础镜像支持 loongarch64
fix_dockerfile() {
    local dockerfile="${TEMPLATE_DIR}/src/Dockerfile"
    if [ ! -f "$dockerfile" ]; then
        die "Dockerfile not found: $dockerfile"
    fi

    log "Fixing Dockerfile for loongarch64 support..."

    # 替换 alpine 版本（3.18 -> 3.24）
    sed -i 's|alpine:3.18|alpine:3.24|g' "$dockerfile"
    
    # 替换 golang 版本为龙芯私有仓库的 Go 镜像
    # 如果龙芯私有仓库有 golang 镜像，使用下面这行
    sed -i 's|golang:1.25-alpine3.24|lcr.loongnix.cn/library/golang:1.25-alpine3.24|g' "$dockerfile"
    
    # 如果龙芯私有仓库没有 golang 镜像，可以尝试使用 golang:1.25-alpine（可能会自动匹配架构）
    # sed -i 's|golang:1.25-alpine3.24|golang:1.25-alpine|g' "$dockerfile"

    log "Dockerfile fixed"
}

# 构建镜像
build_image() {
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local tag="$MAJOR"
    local full_tag="$FULL_VERSION"
    local build_context="${TEMPLATE_DIR}/src"

    if [ ! -d "$build_context" ]; then
        die "Build context $build_context does not exist"
    fi

    log "Building ${image_name}:${tag} from $build_context"
    cd "$build_context" || die "Cannot enter build context"

    docker build --no-cache \
        --build-arg APIFIREWALL_NAMESPACE="github.com/wallarm/api-firewall" \
        --build-arg APIFIREWALL_VERSION="$FULL_VERSION" \
        --force-rm \
        -t "${image_name}:${tag}" \
        -t "${image_name}:${full_tag}" \
        . || die "Build failed"

    cd "$SCRIPT_DIR"
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

prepare_source "$FULL_VERSION"
fix_dockerfile
build_image

# 推送（本地测试时可注释）
 push_image "$MAJOR"
 push_image "$FULL_VERSION"

# 清理源码（可选）
# rm -rf "${TEMPLATE_DIR}/src"

log "Completed $MAJOR ($FULL_VERSION)"
