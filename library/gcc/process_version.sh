#!/bin/bash
set -eo pipefail

# ============================================================
# 处理单个 GCC 主版本（如 13）
# 构建并推送镜像（构建和推送分离，可注释推送进行本地验证）
# 标签：
#   - <主版本号>（如 13）
#   - <完整GCC版本号>（如 13.2.0）
# 注意：不生成 latest 标签
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="gcc"
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
    echo "Usage: $0 <major_version>"
    exit 1
}

# ---------- 校验输入 ----------
validate_input() {
    if [ $# -ne 1 ]; then
        usage
    fi
    MAJOR="$1"
    DOCKERFILE="${TEMPLATE_BASE}/${MAJOR}/Dockerfile"
    if [ ! -f "$DOCKERFILE" ]; then
        die "Dockerfile not found: $DOCKERFILE"
    fi
    GCC_VERSION="$(grep -E '^ENV GCC_VERSION' "$DOCKERFILE" | awk '{print $3}')"
    if [ -z "$GCC_VERSION" ]; then
        die "Cannot find GCC_VERSION in $DOCKERFILE"
    fi
    log "Processing $MAJOR ($GCC_VERSION)"
}

# ---------- 构建镜像 ----------
build_image() {
    local tag="$1"
    local full_tag="$2"
    local dockerfile="$3"
    local build_context="$4"

    log "Building ${REGISTRY}/${ORG}/${PROJ}:${tag}"
    docker build --network host -t "${REGISTRY}/${ORG}/${PROJ}:${tag}" -f "$dockerfile" "$build_context" || die "docker build failed"
    docker tag "${REGISTRY}/${ORG}/${PROJ}:${tag}" "${REGISTRY}/${ORG}/${PROJ}:${full_tag}" || die "docker tag failed"
    log "Build completed for ${REGISTRY}/${ORG}/${PROJ}:${tag} and :${full_tag}"
}

# ---------- 推送镜像 ----------
push_image() {
    local tag="$1"
    local full_tag="$2"

    log "Pushing ${REGISTRY}/${ORG}/${PROJ}:${tag}"
    docker push "${REGISTRY}/${ORG}/${PROJ}:${tag}" || die "docker push failed for ${tag}"
    log "Pushing ${REGISTRY}/${ORG}/${PROJ}:${full_tag}"
    docker push "${REGISTRY}/${ORG}/${PROJ}:${full_tag}" || die "docker push failed for ${full_tag}"
    log "Push completed"
}

# ---------- 主函数 ----------
main() {
    validate_input "$@"

    local tag="$MAJOR"
    local full_tag="$GCC_VERSION"
    local dockerfile="$DOCKERFILE"
    local build_context="${TEMPLATE_BASE}"

    # 构建
    build_image "$tag" "$full_tag" "$dockerfile" "$build_context"

    # 推送（本地测试时注释掉以下行）
    push_image "$tag" "$full_tag"

    log "Completed $MAJOR ($GCC_VERSION)"
}

main "$@"
