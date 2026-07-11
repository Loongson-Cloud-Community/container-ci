#!/bin/bash
set -eo pipefail

# ============================================================
# WordPress 单个系列构建脚本（支持 latest 和 cli）
# 功能：
#   1. 遍历该系列下的所有变体（如 php8.2/apache 等）
#   2. 构建镜像（build_image）和推送（push_image）分离
#   3. 遵循官方标签规范，不生成 latest
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="wordpress"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
VERSIONS_JSON="${TEMPLATE_DIR}/versions.json"

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
    echo "Usage: $0 <series> (latest or cli)"
    exit 1
}

# ---------- 获取完整版本 ----------
get_full_version() {
    local series="$1"
    jq -r ".[\"$series\"].version" "$VERSIONS_JSON" 2>/dev/null || echo ""
}

# ---------- 构建镜像 ----------
build_image() {
    local build_dir="$1"
    local image_name="$2"
    local tag="$3"

    log "Building $image_name:$tag from $build_dir"
    docker build --network host -t "${image_name}:${tag}" "$build_dir" || die "Build failed for $tag"
    log "Build completed for $image_name:$tag"
}

# ---------- 推送镜像 ----------
push_image() {
    local image_name="$1"
    local tag="$2"

    if ! docker image inspect "${image_name}:${tag}" >/dev/null 2>&1; then
        log "ERROR: Image ${image_name}:${tag} not found, skipping push"
        return 1
    fi

    log "Pushing ${image_name}:${tag}"
    docker push "${image_name}:${tag}" || die "Push failed for $tag"
    log "Push completed for ${image_name}:${tag}"
}

# ---------- 生成标签列表 ----------
generate_tags() {
    local series="$1"
    local full_version="$2"
    local major_minor="${full_version%.*}"
    local major="${major_minor%.*}"
    local suffix="$3"          # 如 "php8.2-apache" 或 "php8.2-alpine" (cli)

    local tags=()

    if [ "$series" = "latest" ]; then
        if [[ "$suffix" =~ ^php([0-9.]+)-(apache|fpm|fpm-alpine)$ ]]; then
            local php_ver="${BASH_REMATCH[1]}"
            local variant_type="${BASH_REMATCH[2]}"

            tags+=("$full_version-$suffix")
            tags+=("$major_minor-$suffix")
            tags+=("$major-$suffix")
            tags+=("$suffix")

            if [ "$php_ver" = "8.3" ]; then
                tags+=("$full_version-$variant_type")
                tags+=("$major_minor-$variant_type")
                tags+=("$major-$variant_type")
                tags+=("$variant_type")
                if [ "$variant_type" = "apache" ]; then
                    tags+=("$full_version")
                    tags+=("$major_minor")
                    tags+=("$major")
                fi
            fi
        else
            log "WARNING: Unrecognized suffix format: $suffix"
        fi
    elif [ "$series" = "cli" ]; then
        # CLI 变体只有 alpine，suffix 为 "php8.2-alpine"
        # 生成标签：cli-<version>-<suffix>, cli-<major_minor>-<suffix>, cli-<major>-<suffix>, cli-<suffix>
        tags+=("cli-$full_version-$suffix")
        tags+=("cli-$major_minor-$suffix")
        tags+=("cli-$major-$suffix")
        tags+=("cli-$suffix")
        # 不带 php 版本的 CLI 标签（简写）
        tags+=("cli-$full_version")
        tags+=("cli-$major_minor")
        tags+=("cli-$major")
        tags+=("cli")
    fi

    printf "%s\n" "${tags[@]}" | sort -u
}

# ---------- 主函数 ----------
main() {
    if [ $# -ne 1 ]; then
        usage
    fi
    local series="$1"

    local full_version
    full_version="$(get_full_version "$series")"
    if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
        die "Cannot find version for series $series"
    fi
    log "Building WordPress $series ($full_version)"

    if [ ! -d "${TEMPLATE_DIR}/$series" ]; then
        die "Directory ${TEMPLATE_DIR}/$series not found"
    fi

    local image_name="${REGISTRY}/${ORG}/${PROJ}"

    while IFS= read -r dockerfile; do
        local build_dir
        build_dir="$(dirname "$dockerfile")"
        local rel_path="${build_dir#${TEMPLATE_DIR}/}"
        local suffix
        if [ "$series" = "cli" ]; then
            suffix="$(basename "$build_dir")"   # 如 php8.2-alpine
        else
            suffix="$(echo "$rel_path" | cut -d/ -f2- | tr '/' '-')"  # php8.2-apache
        fi

        local tags
        tags="$(generate_tags "$series" "$full_version" "$suffix")"
        if [ -z "$tags" ]; then
            log "WARNING: No tags generated for $rel_path, skipping"
            continue
        fi
        mapfile -t tags_array <<< "$tags"
        local specific_tag="${tags_array[0]}"
        local aliases=("${tags_array[@]}")

        # 构建主标签
        build_image "$build_dir" "$image_name" "$specific_tag"

        # 打别名标签
        for alias in "${aliases[@]}"; do
            if [ "$alias" != "$specific_tag" ]; then
                docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}" || die "Tagging $alias failed"
                log "Tagged ${image_name}:${specific_tag} as ${image_name}:${alias}"
            fi
        done

        # 推送所有标签
        push_image "$image_name" "$specific_tag"
        for alias in "${aliases[@]}"; do
            if [ "$alias" != "$specific_tag" ]; then
                push_image "$image_name" "$alias"
            fi
        done

    done < <(find "${TEMPLATE_DIR}/$series" -name Dockerfile -type f 2>/dev/null || true)

    log "Completed series $series"
}

main "$@"
