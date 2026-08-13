#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="cassandra"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
VERSIONS_JSON="${TEMPLATE_DIR}/versions.json"

source "${SCRIPT_DIR}/lib.sh"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <major_version>"
    exit 1
fi

MAJOR="$1"

if [ ! -f "$VERSIONS_JSON" ]; then
    die "$VERSIONS_JSON not found. Run ci.sh first."
fi

FULL_VERSION=$(jq -r ".\"$MAJOR\".version" "$VERSIONS_JSON")
if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
    die "Cannot find version for $MAJOR in $VERSIONS_JSON"
fi

log "Processing $MAJOR ($FULL_VERSION)"

# 判断是否该系列最新版本
is_latest=false
major_num=$(echo "$MAJOR" | cut -d. -f1)
all_versions=$(jq -r 'keys[]' "$VERSIONS_JSON")
same_major_versions=$(echo "$all_versions" | grep "^${major_num}\." || true)
if [ -n "$same_major_versions" ]; then
    # 找出最新版本（按 fullVersion 排序）
    latest_short=$(echo "$same_major_versions" | while read ver; do
        full=$(jq -r ".\"$ver\".version" "$VERSIONS_JSON")
        echo "$ver $full"
    done | sort -k2 -V | tail -1 | awk '{print $1}')
    if [ "$MAJOR" = "$latest_short" ]; then
        is_latest=true
    fi
fi

# 构建镜像
build_and_push() {
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local build_dir="$TEMPLATE_DIR/$MAJOR"
    local tags=()

    # 基础标签
    tags+=("${image_name}:${FULL_VERSION}")
    tags+=("${image_name}:${MAJOR}")
    tags+=("${image_name}:${FULL_VERSION}-forky")
    tags+=("${image_name}:${MAJOR}-forky")

    # 如果是该系列最新，添加短别名
    if [ "$is_latest" = true ]; then
        short_alias="${major_num}"
        tags+=("${image_name}:${short_alias}")
        tags+=("${image_name}:${short_alias}-forky")
    fi

    # 去重（可能有重复）
    tags=($(printf "%s\n" "${tags[@]}" | sort -u))

    if [ ! -d "$build_dir" ]; then
        die "Build directory $build_dir does not exist"
    fi

    log "Building ${image_name}:${MAJOR} from $build_dir"
    docker build --network host -t "${image_name}:${MAJOR}" -f "$build_dir/Dockerfile" "$build_dir" || die "Build failed"

    # 打标签
    for tag in "${tags[@]}"; do
        if [ "$tag" != "${image_name}:${MAJOR}" ]; then
            docker tag "${image_name}:${MAJOR}" "$tag"
            log "Tagged ${image_name}:${MAJOR} as $tag"
        fi
    done

    # 推送（本地测试时可注释）
    for tag in "${tags[@]}"; do
         docker push "$tag" || die "Push failed for $tag"
    done

    log "Build completed for ${image_name}:${MAJOR} with tags: ${tags[*]}"
}

build_and_push

log "Completed $MAJOR ($FULL_VERSION)"
