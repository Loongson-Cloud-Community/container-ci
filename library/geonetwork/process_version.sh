#!/bin/bash
set -eo pipefail

# ============================================================
# 处理单个 GeoNetwork 版本（支持 4.4.x）
# 流程：
#   1. 执行 update.sh 更新 Dockerfile（若失败则继续）
#   2. 替换基础镜像为私有仓库地址（tomcat 和 jetty）
#   3. 构建镜像并推送（无 latest）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="geonetwork"
TEMPLATE_DIR="${SCRIPT_DIR}/template"

source "${SCRIPT_DIR}/lib.sh"

usage() {
    echo "Usage: $0 <version>"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi
VERSION="$1"

# ---------- 更新 Dockerfile（若失败则继续） ----------
update_dockerfile() {
    log "Updating Dockerfile for version $VERSION using template/update.sh"
    cd "$TEMPLATE_DIR" || die "Cannot enter template directory"
    if ./update.sh "$VERSION" 2>/dev/null; then
        log "update.sh succeeded"
    else
        log "WARNING: update.sh failed for $VERSION, but continuing with existing Dockerfile"
    fi
    cd "$SCRIPT_DIR" || die "Cannot return to script dir"
}

# ---------- 替换基础镜像为私有仓库 ----------
fix_base_image() {
    local build_dir="$1"
    local dockerfile="$build_dir/Dockerfile"
    if [ ! -f "$dockerfile" ]; then
        die "Dockerfile not found: $dockerfile"
    fi
    log "Replacing base images with private registry in $dockerfile"
    # 替换 tomcat 基础镜像，提取核心标签（如 9-jre11, 10-jdk17 等）
    sed -i -E '
        # 匹配 tomcat:版本-变体-发行版（如 9-jre11-temurin-noble）
        s|^FROM tomcat:([0-9]+-[a-z]+[0-9]+)-[a-z]+-[a-z]+|FROM lcr.loongnix.cn/library/tomcat:\1|;
        # 如果没有发行版后缀，直接添加仓库前缀
        s|^FROM tomcat:([0-9]+-[a-z]+[0-9]+)|FROM lcr.loongnix.cn/library/tomcat:\1|
    ' "$dockerfile"
    # 替换 jetty 基础镜像（如果存在）
    sed -i 's|^FROM jetty:|FROM lcr.loongnix.cn/library/jetty:|' "$dockerfile"
    log "Base images replaced"
}

# ---------- 构建镜像 ----------
build_image() {
    local build_dir="$1"
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local tag="$VERSION"

    log "Building ${image_name}:${tag} from $build_dir"
    docker build --no-cache --network host -t "${image_name}:${tag}" -f "$build_dir/Dockerfile" "$build_dir" || die "Build failed"
    log "Build completed for ${image_name}:${tag}"
}

# ---------- 推送镜像 ----------
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

# ---------- 生成标签 ----------
generate_tags() {
    local full_version="$VERSION"
    local major_minor="${full_version%.*}"
    local major="${major_minor%.*}"

    echo "$full_version"
    echo "$major_minor"
    echo "$major"
}

# ---------- 主函数 ----------
main() {
    update_dockerfile

    local build_dir="$TEMPLATE_DIR/$VERSION"
    if [ ! -d "$build_dir" ]; then
        die "Build directory $build_dir does not exist"
    fi

    # 修正基础镜像
    fix_base_image "$build_dir"

    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local tags
    tags="$(generate_tags)"

    # 构建主标签
    build_image "$build_dir"

    # 打别名标签
    for tag in $tags; do
        if [ "$tag" != "$VERSION" ]; then
            docker tag "${image_name}:${VERSION}" "${image_name}:${tag}" || die "Tagging $tag failed"
            log "Tagged ${image_name}:${VERSION} as ${image_name}:${tag}"
        fi
    done

    # 推送所有标签
#    for tag in $tags; do
#        push_image "$tag"
#    done

    log "Completed version $VERSION"
}

main
