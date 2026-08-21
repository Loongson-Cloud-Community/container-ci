#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="tomcat"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"
TEMPLATE_BASE="${SCRIPT_DIR}/template"

# ---------- 日志函数 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ---------- 错误函数 ----------
# 用法：error "message"          # 仅打印红色错误
#       error "message" true     # 打印红色错误并退出
error() {
    echo -e "\033[31m[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1\033[0m" >&2
    if [ "${2:-false}" = "true" ]; then
        exit 1
    fi
}

usage() {
    echo "Usage: $0 <major_version>"
    exit 1
}

validate_input() {
    if [ $# -ne 1 ]; then
        usage
    fi
    if [ ! -f "$VERSIONS_JSON" ]; then
        error "$VERSIONS_JSON not found. Run ci.sh first." true
    fi
    MAJOR="$1"
    FULL_VERSION="$(jq -r ".\"$MAJOR\".version" "$VERSIONS_JSON")"
    if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
        error "Cannot find version for $MAJOR in $VERSIONS_JSON" true
    fi
    TAG_VERSION="$(echo "$FULL_VERSION" | tr '+' '_')"
    log "Processing $MAJOR ($FULL_VERSION) -> tag version: $TAG_VERSION"
}

build_and_push() {
    local dockerfile="$1"
    local build_context="$2"
    local base_tag="$3"
    shift 3
    local extra_tags=("$@")

    if [ ! -f "$dockerfile" ]; then
        log "WARNING: Dockerfile not found: $dockerfile"
        return 0
    fi

    log "Building $base_tag from $dockerfile"
    docker build --no-cache --network host -t "$base_tag" -f "$dockerfile" "$build_context" || {
        error "docker build failed for $base_tag"
        return 1
    }

    for tag in "${extra_tags[@]}"; do
        docker tag "$base_tag" "$tag" || {
            error "docker tag failed for $tag"
            return 1
        }
        log "Tagged $base_tag as $tag"
    done

    docker push "$base_tag" || {
        error "docker push failed for $base_tag"
        return 1
    }
    for tag in "${extra_tags[@]}"; do
        docker push "$tag" || {
            error "docker push failed for $tag"
            return 1
        }
    done
}

generate_tags() {
    local variant_type="$1"        # jdk 或 jre
    local java_version="$2"        # 8,11,17,21,25
    local major="$3"
    local tag_version="$4"
    local registry_org_proj="$5"

    local base_tag=""
    local extra_tags=()

    # 1. 带发行版后缀（-forky）和 temurin 标识
    base_tag="${registry_org_proj}:${major}-${variant_type}${java_version}-temurin-forky"
    extra_tags=(
        "${registry_org_proj}:${tag_version}-${variant_type}${java_version}-temurin-forky"
        # 2. 不带发行版后缀，但保留 temurin
        "${registry_org_proj}:${major}-${variant_type}${java_version}-temurin"
        "${registry_org_proj}:${tag_version}-${variant_type}${java_version}-temurin"
        # 3. 完全简化版，不带 temurin
        "${registry_org_proj}:${major}-${variant_type}${java_version}"
        "${registry_org_proj}:${tag_version}-${variant_type}${java_version}"
    )

    # 4. 对所有变体生成短别名（如 9-jdk11, 9-jre11）
    local major_num="${major%%.*}"
    if [ "$major_num" != "$major" ]; then
        extra_tags+=(
            "${registry_org_proj}:${major_num}-${variant_type}${java_version}-temurin-forky"
            "${registry_org_proj}:${major_num}-${variant_type}${java_version}-temurin"
            "${registry_org_proj}:${major_num}-${variant_type}${java_version}"
        )
    fi

    # 5. 对 JDK 25（最新版本）额外生成通用版本标签（不带 Java 版本和 variant_type）
    if [[ "$variant_type" == "jdk" && "$java_version" == "25" ]]; then
        extra_tags+=(
            "${registry_org_proj}:${major}-temurin"
            "${registry_org_proj}:${tag_version}-temurin"
            "${registry_org_proj}:${major}"
            "${registry_org_proj}:${tag_version}"
        )
        if [ "$major_num" != "$major" ]; then
            extra_tags+=(
                "${registry_org_proj}:${major_num}-temurin"
                "${registry_org_proj}:${major_num}"
            )
        fi
    fi

    echo "$base_tag"
    for tag in "${extra_tags[@]}"; do
        echo "$tag"
    done
    return 0
}

# ---------- 构建单个变体 ----------
build_variant() {
    local dockerfile="$1"
    local major="$2"
    local tag_version="$3"
    local registry_org_proj="$4"

    local variant_dir="$(dirname "$dockerfile")"
    local java_dir="$(basename "$(dirname "$variant_dir")")"
    local variant_type
    local java_version

    if [[ "$java_dir" == jdk* ]]; then
        variant_type="jdk"
        java_version="${java_dir#jdk}"
    elif [[ "$java_dir" == jre* ]]; then
        variant_type="jre"
        java_version="${java_dir#jre}"
    else
        log "WARNING: Unknown java dir: $java_dir, skipping"
        return 0
    fi

    local base_image="$(basename "$variant_dir")"
    if [[ "$base_image" != "temurin" ]]; then
        log "Skipping non-temurin variant: $variant_dir"
        return 0
    fi

    local tag_list
    tag_list="$(generate_tags "$variant_type" "$java_version" "$major" "$tag_version" "$registry_org_proj")" || {
        error "Failed to generate tags for $variant_dir"
        return 1
    }
    if [ -z "$tag_list" ]; then
        log "WARNING: No tags generated for $variant_dir, skipping"
        return 0
    fi

    mapfile -t tags_array <<< "$tag_list"
    local base_tag="${tags_array[0]}"
    local extra_tags=("${tags_array[@]:1}")

    build_and_push "$dockerfile" "$variant_dir" "$base_tag" "${extra_tags[@]}"
}

# ---------- 处理所有变体（JDK 优先） ----------
process_all_variants() {
    local major="$1"
    local tag_version="$2"
    local registry_org_proj="${REGISTRY}/${ORG}/${PROJ}"

    # 收集所有 JDK 和 JRE 的 Dockerfile
    local jdk_files=()
    local jre_files=()

    while IFS= read -r dockerfile; do
        # 判断是 jdk 还是 jre
        if [[ "$dockerfile" =~ /jdk[0-9]+/temurin/Dockerfile$ ]]; then
            jdk_files+=("$dockerfile")
        elif [[ "$dockerfile" =~ /jre[0-9]+/temurin/Dockerfile$ ]]; then
            jre_files+=("$dockerfile")
        fi
    done < <(find "$TEMPLATE_BASE/$major" -type f \( -path "*/jdk*/temurin/Dockerfile" -o -path "*/jre*/temurin/Dockerfile" \) 2>/dev/null || true)

    # 检查是否有任何变体
    if [ ${#jdk_files[@]} -eq 0 ] && [ ${#jre_files[@]} -eq 0 ]; then
        log "WARNING: No variants found for $major"
        return 0
    fi

    # 第一轮：构建所有 JDK 变体
    if [ ${#jdk_files[@]} -gt 0 ]; then
        log "=== Building JDK variants for $major ($tag_version) ==="
        for dockerfile in "${jdk_files[@]}"; do
            build_variant "$dockerfile" "$major" "$tag_version" "$registry_org_proj"
        done
    else
        log "No JDK variants found for $major"
    fi

    # 第二轮：构建所有 JRE 变体（依赖 JDK 镜像已存在）
    if [ ${#jre_files[@]} -gt 0 ]; then
        log "=== Building JRE variants for $major ($tag_version) ==="
        for dockerfile in "${jre_files[@]}"; do
            build_variant "$dockerfile" "$major" "$tag_version" "$registry_org_proj"
        done
    else
        log "No JRE variants found for $major"
    fi
}

main() {
    validate_input "$@"
    process_all_variants "$MAJOR" "$TAG_VERSION"
    log "Completed $MAJOR ($FULL_VERSION)"
}

main "$@"
