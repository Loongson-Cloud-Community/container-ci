#!/bin/bash
set -eo pipefail

# ============================================================
# 构建并推送单个 Jetty 大版本的所有变体镜像
# 支持 JDK 和 JRE 变体，标签与上游保持一致
# 根据大版本动态适配 Java 版本
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="jetty"
VERSIONS_JSON="${SCRIPT_DIR}/versions.json"

# ---------- 日志函数 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ---------- 错误处理 ----------
die() {
    log "ERROR: $*" >&2
    exit 1
}

# ---------- 检查命令 ----------
check_dependencies() {
    command -v docker >/dev/null 2>&1 || die "docker is required"
    command -v jq >/dev/null 2>&1 || die "jq is required"
}

# ---------- 构建并推送镜像 ----------
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
    docker build --network host -t "$base_tag" -f "$dockerfile" "$build_context" || die "docker build failed for $base_tag"

    for tag in "${extra_tags[@]}"; do
        docker tag "$base_tag" "$tag" || die "docker tag failed for $tag"
        log "Tagged $base_tag as $tag"
    done

#    docker push "$base_tag" || die "docker push failed for $base_tag"
#    for tag in "${extra_tags[@]}"; do
#        docker push "$tag" || die "docker push failed for $tag"
#    done
}

# ---------- 生成标签列表 ----------
generate_tags() {
    local base_image="$1"       # debian 或 alpine
    local variant_type="$2"     # jdk 或 jre
    local java_version="$3"     # 11,17,21,25
    local major="$4"            # 如 12.1, 9.4
    local tag_version="$5"      # 如 12.1.11
    local registry_org_proj="$6"

    local tags=()

    # 1. 带 Java 版本的主要标签（包含 -eclipse-temurin 和不带）
    if [[ "$base_image" == "alpine" ]]; then
        # 带 -eclipse-temurin
        tags+=("${registry_org_proj}:${major}-${variant_type}${java_version}-alpine-eclipse-temurin")
        tags+=("${registry_org_proj}:${tag_version}-${variant_type}${java_version}-alpine-eclipse-temurin")
        # 不带 -eclipse-temurin
        tags+=("${registry_org_proj}:${major}-${variant_type}${java_version}-alpine")
        tags+=("${registry_org_proj}:${tag_version}-${variant_type}${java_version}-alpine")
    else
        tags+=("${registry_org_proj}:${major}-${variant_type}${java_version}-eclipse-temurin")
        tags+=("${registry_org_proj}:${tag_version}-${variant_type}${java_version}-eclipse-temurin")
        tags+=("${registry_org_proj}:${major}-${variant_type}${java_version}")
        tags+=("${registry_org_proj}:${tag_version}-${variant_type}${java_version}")
    fi

    # 2. 对 JDK 且为最新 Java 版本（25），生成不带 Java 版本和 variant_type 的通用标签
    #    （这些标签不带 -eclipse-temurin 和带 -eclipse-temurin 的版本均已生成）
    if [[ "$variant_type" == "jdk" && "$java_version" == "25" ]]; then
        if [[ "$base_image" == "alpine" ]]; then
            tags+=("${registry_org_proj}:${major}-alpine-eclipse-temurin")
            tags+=("${registry_org_proj}:${tag_version}-alpine-eclipse-temurin")
            tags+=("${registry_org_proj}:${major}-alpine")
            tags+=("${registry_org_proj}:${tag_version}-alpine")
        else
            tags+=("${registry_org_proj}:${major}-eclipse-temurin")
            tags+=("${registry_org_proj}:${tag_version}-eclipse-temurin")
            tags+=("${registry_org_proj}:${major}")
            tags+=("${registry_org_proj}:${tag_version}")
        fi
    fi

    # 3. 对 Jetty 9（major == "9.4"），额外生成以 "9" 开头的短别名
    if [[ "$major" == "9.4" ]]; then
        local short_major="9"
        if [[ "$base_image" == "alpine" ]]; then
            tags+=("${registry_org_proj}:${short_major}-${variant_type}${java_version}-alpine-eclipse-temurin")
            tags+=("${registry_org_proj}:${short_major}-${variant_type}${java_version}-alpine")
        else
            tags+=("${registry_org_proj}:${short_major}-${variant_type}${java_version}-eclipse-temurin")
            tags+=("${registry_org_proj}:${short_major}-${variant_type}${java_version}")
        fi
        # 如果是最新 Java 版本，也生成不带 Java 版本的短别名
        if [[ "$variant_type" == "jdk" && "$java_version" == "25" ]]; then
            if [[ "$base_image" == "alpine" ]]; then
                tags+=("${registry_org_proj}:${short_major}-alpine-eclipse-temurin")
                tags+=("${registry_org_proj}:${short_major}-alpine")
            else
                tags+=("${registry_org_proj}:${short_major}-eclipse-temurin")
                tags+=("${registry_org_proj}:${short_major}")
            fi
        fi
    fi

    # 去重并输出
    printf "%s\n" "${tags[@]}" | sort -u
}

# ---------- 处理单个变体 ----------
process_variant() {
    local base_image="$1"       # debian 或 alpine
    local variant_type="$2"     # jdk 或 jre
    local java_version="$3"     # 11,17,21,25
    local major="$4"
    local tag_version="$5"
    local registry_org_proj="$6"

    local target_dir="template/eclipse-temurin/$major/${variant_type}${java_version}"
    if [[ "$base_image" == "alpine" ]]; then
        target_dir="${target_dir}-alpine"
    fi
    local dockerfile="$target_dir/Dockerfile"

    if [ ! -f "$dockerfile" ]; then
        log "WARNING: $dockerfile not found, skipping"
        return 0
    fi

    local tag_list
    tag_list="$(generate_tags "$base_image" "$variant_type" "$java_version" "$major" "$tag_version" "$registry_org_proj")"
    mapfile -t tags_array <<< "$tag_list"
    local base_tag="${tags_array[0]}"
    local extra_tags=("${tags_array[@]:1}")

    build_and_push "$dockerfile" "$target_dir" "$base_tag" "${extra_tags[@]}"
}

# ---------- 主函数 ----------
main() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <major_version>"
        exit 1
    fi
    local major="$1"

    check_dependencies

    if [ ! -f "$VERSIONS_JSON" ]; then
        die "$VERSIONS_JSON not found. Run fetch_versions.sh first."
    fi
    local full_version
    full_version="$(jq -r ".\"$major\"" "$VERSIONS_JSON")"
    if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
        die "Cannot find version for $major in $VERSIONS_JSON"
    fi

    log "Processing $major ($full_version)"

    # 定义每个大版本支持的 Java 版本
    declare -A SUPPORTED_JAVA_VERSIONS=(
        ["9.4"]="11 17 21 25"
        ["10"]="11 17 21 25"
        ["12.0"]="17 21 25"
        ["12.1"]="17 21 25"
    )

    local java_versions="${SUPPORTED_JAVA_VERSIONS[$major]}"
    if [ -z "$java_versions" ]; then
        die "Unsupported major version $major"
    fi

    # 构建变体列表
    local VARIANTS=()
    for java_ver in $java_versions; do
        VARIANTS+=("debian:jdk$java_ver" "alpine:jdk$java_ver")
        VARIANTS+=("debian:jre$java_ver" "alpine:jre$java_ver")
    done

    local registry_org_proj="${REGISTRY}/${ORG}/${PROJ}"

    for variant in "${VARIANTS[@]}"; do
        IFS=':' read -r base_image variant_spec <<< "$variant"
        if [[ "$variant_spec" == jdk* ]]; then
            variant_type="jdk"
            java_version="${variant_spec#jdk}"
        elif [[ "$variant_spec" == jre* ]]; then
            variant_type="jre"
            java_version="${variant_spec#jre}"
        else
            log "WARNING: Invalid variant spec: $variant_spec"
            continue
        fi
        process_variant "$base_image" "$variant_type" "$java_version" "$major" "$full_version" "$registry_org_proj"
    done

    log "Completed $major ($full_version)"
}

main "$@"
