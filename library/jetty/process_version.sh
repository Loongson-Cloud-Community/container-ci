#!/bin/bash
set -eo pipefail

# ============================================================
# 构建并推送单个 Jetty 大版本的所有变体镜像
# 支持 JDK 和 JRE 变体，标签与上游保持一致
# 标签格式：
#   Debian JDK:  <major>-jdk<JavaVer>-eclipse-temurin
#   Debian JRE:  <major>-jre<JavaVer>-eclipse-temurin
#   Alpine JDK:  <major>-jdk<JavaVer>-alpine-eclipse-temurin
#   Alpine JRE:  <major>-jre<JavaVer>-alpine-eclipse-temurin
#   （同时生成完整版本标签）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="jetty"
VERSIONS_JSON="${SCRIPT_DIR}/versions.json"

# ---------- 变体定义 ----------
# 格式: "<base>:<variant_spec>"
# base: "debian" 或 "alpine"
# variant_spec: "jdk17", "jdk21", "jdk25", "jre17", "jre21", "jre25"
VARIANTS=(
    "debian:jdk17" "alpine:jdk17"
    "debian:jdk21" "alpine:jdk21"
    "debian:jdk25" "alpine:jdk25"
    "debian:jre17" "alpine:jre17"
    "debian:jre21" "alpine:jre21"
    "debian:jre25" "alpine:jre25"
)

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

    docker push "$base_tag" || die "docker push failed for $base_tag"
    for tag in "${extra_tags[@]}"; do
        docker push "$tag" || die "docker push failed for $tag"
    done
}

# ---------- 生成标签列表 ----------
generate_tags() {
    local base_image="$1"       # debian 或 alpine
    local variant_type="$2"     # jdk 或 jre
    local java_version="$3"     # 17,21,25
    local major="$4"
    local tag_version="$5"
    local registry_org_proj="$6"

    local base_tag=""
    local extra_tags=()

    if [[ "$base_image" == "alpine" ]]; then
        base_tag="${registry_org_proj}:${major}-${variant_type}${java_version}-alpine-eclipse-temurin"
        extra_tags+=(
            "${registry_org_proj}:${tag_version}-${variant_type}${java_version}-alpine-eclipse-temurin"
        )
    else
        base_tag="${registry_org_proj}:${major}-${variant_type}${java_version}-eclipse-temurin"
        extra_tags+=(
            "${registry_org_proj}:${tag_version}-${variant_type}${java_version}-eclipse-temurin"
        )
    fi

    echo "$base_tag"
    for tag in "${extra_tags[@]}"; do
        echo "$tag"
    done
}

# ---------- 处理单个变体 ----------
process_variant() {
    local base_image="$1"       # debian 或 alpine
    local variant_type="$2"     # jdk 或 jre
    local java_version="$3"     # 17,21,25
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
