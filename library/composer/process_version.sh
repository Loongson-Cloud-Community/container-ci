#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
VERSIONS_JSON="${SCRIPT_DIR}/versions.json"

# 导入公共函数
source "${SCRIPT_DIR}/lib.sh"

# 配置
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="composer"
PHP_BASE_IMAGE="${REGISTRY}/library/php:8.5-alpine"

# 用法检查
if [ $# -ne 1 ]; then
    echo "Usage: $0 <major_version>"
    echo "Example: $0 2.2"
    exit 1
fi

MAJOR="$1"

# 检查 versions.json 是否存在
if [ ! -f "$VERSIONS_JSON" ]; then
    die "$VERSIONS_JSON not found. Run fetch_versions.sh first."
fi

# 获取完整版本号
FULL_VERSION=$(jq -r ".\"$MAJOR\"" "$VERSIONS_JSON")
if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
    die "Cannot find version for $MAJOR in $VERSIONS_JSON"
fi

log "Processing $MAJOR ($FULL_VERSION)"

# 修改基础镜像地址
fix_base_image() {
    local dockerfile="$TEMPLATE_DIR/$MAJOR/Dockerfile"
    if [ ! -f "$dockerfile" ]; then
        die "Dockerfile not found: $dockerfile"
    fi
    
    log "Fixing base image in $dockerfile"
    log "Replacing FROM php:8-alpine with FROM $PHP_BASE_IMAGE"
    
    # 备份原文件
    cp "$dockerfile" "${dockerfile}.bak"
    
    # 使用 sed 替换基础镜像
    sed -i "s|FROM php:[0-9.]*-alpine|FROM $PHP_BASE_IMAGE|g" "$dockerfile"
    
    # 验证修改是否成功
    if grep -q "^FROM $PHP_BASE_IMAGE" "$dockerfile"; then
        log "Base image fixed successfully"
        rm -f "${dockerfile}.bak"
    else
        log "WARNING: Base image may not have been replaced correctly"
        # 恢复备份
        mv "${dockerfile}.bak" "$dockerfile"
        die "Failed to fix base image"
    fi
}

# 构建镜像
build_image() {
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local build_dir="$TEMPLATE_DIR/$MAJOR"
    
    if [ ! -d "$build_dir" ]; then
        die "Build directory $build_dir does not exist"
    fi
    
    log "Building ${image_name}:${MAJOR} and ${image_name}:${FULL_VERSION}"
    log "Build context: $build_dir"
    
    # 构建镜像，同时打两个标签
    docker build \
        --no-cache \
        --network host \
        -t "${image_name}:${MAJOR}" \
        -t "${image_name}:${FULL_VERSION}" \
        -f "$build_dir/Dockerfile" \
        "$build_dir" || die "Build failed"
    
    log "Build completed successfully"
    log "Images: ${image_name}:${MAJOR}, ${image_name}:${FULL_VERSION}"
}

# 推送镜像（可选）
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

# 主流程
main() {
    fix_base_image
    build_image
    
    # 推送镜像（生产环境启用，测试时可注释）
    # push_image "$MAJOR"
    # push_image "$FULL_VERSION"
    
    log "Completed processing $MAJOR ($FULL_VERSION)"
    
    # 显式返回成功
    return 0
}

main "$@"
