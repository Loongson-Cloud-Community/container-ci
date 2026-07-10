#!/bin/bash
set -eo pipefail

# ============================================================
# 构建并推送 Traefik 指定版本镜像
# 流程：
#   1. 克隆源码并 checkout 指定 tag
#   2. 应用补丁（若有）
#   3. 编译 LoongArch 二进制
#   4. 准备构建上下文并构建镜像
#   5. 推送标签（版本号、主次版本、主版本，无 latest）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="traefik"
REPO_URL="https://github.com/traefik/traefik.git"
TEMPLATE_BASE="${SCRIPT_DIR}/template"

# ---------- 日志 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ---------- 错误处理 ----------
die() {
    log "ERROR: $*" >&2
    exit 1
}

# ---------- 用法 ----------
usage() {
    echo "Usage: $0 <version>"
    exit 1
}

# ---------- 校验输入 ----------
validate_input() {
    if [ $# -ne 1 ]; then
        usage
    fi
    VERSION="$1"
    TAG="v$VERSION"
    log "Processing version $VERSION (tag $TAG)"
}

# ---------- 克隆仓库 ----------
clone_repo() {
    local work_dir="$1"
    log "Cloning Traefik repository (tag $TAG)..."
    git clone --depth 1 --branch "$TAG" "$REPO_URL" "$work_dir" || die "git clone failed"
}

# ---------- 应用补丁 ----------
apply_patches() {
    local work_dir="$1"
    local patches_dir="${SCRIPT_DIR}/patches"
    if [ ! -d "$patches_dir" ]; then
        log "WARNING: Patches directory not found, skipping"
        return 0
    fi
    log "Applying patches from $patches_dir..."
    cd "$work_dir" || die "Cannot enter work directory"
    for patch_file in "$patches_dir"/*.patch; do
        if [ -f "$patch_file" ]; then
            log "Applying $patch_file"
            patch -p1 < "$patch_file" || die "Failed to apply $patch_file"
        fi
    done
    cd - >/dev/null || die "Cannot return"
}

# ---------- 构建二进制 ----------
build_binary() {
    local work_dir="$1"
    log "Building Traefik binary for loong64..."
    cd "$work_dir" || die "Cannot enter work directory"
    make binary-linux-loong64 || die "make failed"
    cd - >/dev/null || die "Cannot return"
}

# ---------- 准备构建上下文 ----------
prepare_build_context() {
    local work_dir="$1"
    log "Preparing build context in template directory..."

    # 确保 template 目录存在
    mkdir -p "$TEMPLATE_BASE"

    # 如果 Dockerfile 不存在，则从源码复制一份并修改
    if [ ! -f "$TEMPLATE_BASE/Dockerfile" ]; then
        log "Dockerfile not found in template, copying from source..."
        cp "$work_dir/Dockerfile" "$TEMPLATE_BASE/Dockerfile" || die "Cannot copy Dockerfile from source"
        # 修改基础镜像和换源逻辑
        sed -i 's|^FROM alpine:.*$|FROM lcr.loongnix.cn/library/alpine:3.24|' "$TEMPLATE_BASE/Dockerfile"
        sed -i '/RUN apk add/i RUN apk update || (sed -i '\''s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g'\'' /etc/apk/repositories && apk update)' "$TEMPLATE_BASE/Dockerfile"
    fi

    # 复制二进制文件（覆盖旧文件）
    mkdir -p "$TEMPLATE_BASE/dist/linux/loong64"
    cp "$work_dir/dist/linux/loong64/traefik" "$TEMPLATE_BASE/dist/linux/loong64/" || die "Cannot copy traefik binary"
}

# ---------- 构建并推送镜像 ----------
build_and_push() {
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local version="$VERSION"
    local major_minor="${version%.*}"
    local major="${version%%.*}"

    log "Building ${image_name}:${version}"
    docker build --network host -t "${image_name}:${version}" "$TEMPLATE_BASE" || die "docker build failed"

    # 推送标签（无 latest）
    local tags=("$version" "$major_minor" "$major")
    for tag in "${tags[@]}"; do
        docker tag "${image_name}:${version}" "${image_name}:${tag}" || die "docker tag failed for $tag"
        log "Pushing ${image_name}:${tag}"
        docker push "${image_name}:${tag}" || die "docker push failed for $tag"
    done

    log "Push completed for version $version"
}

# ---------- 清理 ----------
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log "Cleaned up temporary directory"
    fi
}

# ---------- 主函数 ----------
main() {
    validate_input "$@"

    TEMP_DIR="$(mktemp -d)"
    trap cleanup EXIT

    clone_repo "$TEMP_DIR"
    apply_patches "$TEMP_DIR"
    build_binary "$TEMP_DIR"
    prepare_build_context "$TEMP_DIR"
    build_and_push

    log "Completed processing version $VERSION"
}

main "$@"
