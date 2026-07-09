#!/bin/bash
set -Eeuo pipefail

# ============================================================
# 处理单个 Tomcat 大版本（如 9.0）
# 功能：
#   1. 遍历该大版本下所有变体（jdk*/{debian-forky,temurin}）
#   2. 为每个变体生成符合官方规范的标签
#   3. 构建并推送镜像
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="tomcat"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"   # 从 template 下读取
TEMPLATE_BASE="${SCRIPT_DIR}/template"

# ---------- 日志 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
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
    if [ ! -f "$VERSIONS_JSON" ]; then
        log "ERROR: $VERSIONS_JSON not found. Run ci.sh first."
        exit 1
    fi
    MAJOR="$1"
    FULL_VERSION="$(jq -r ".\"$MAJOR\".version" "$VERSIONS_JSON")"
    if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
        log "ERROR: Cannot find version for $MAJOR in $VERSIONS_JSON"
        exit 1
    fi
    TAG_VERSION="$(echo "$FULL_VERSION" | tr '+' '_')"
    log "Processing $MAJOR ($FULL_VERSION) -> tag version: $TAG_VERSION"
}

# ---------- 构建并推送 ----------
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
    docker build --network host -t "$base_tag" -f "$dockerfile" "$build_context"

    for tag in "${extra_tags[@]}"; do
        docker tag "$base_tag" "$tag"
        log "Tagged $base_tag as $tag"
    done

    docker push "$base_tag"
    for tag in "${extra_tags[@]}"; do
        docker push "$tag"
    done
}

# ---------- 生成标签（核心，可扩展） ----------
generate_tags() {
    local variant_type="$1"        # jdk 或 jre
    local base_image="$2"          # debian-forky 或 temurin
    local java_version="$3"        # 8,11,17,21,25
    local major="$4"
    local tag_version="$5"
    local registry_org_proj="$6"

    local base_tag=""
    local extra_tags=()

    # 可扩展的标签生成规则
    case "$base_image" in
        debian-forky)
            if [ "$variant_type" = "jdk" ]; then
                base_tag="${registry_org_proj}:${major}"
                extra_tags=(
                    "${registry_org_proj}:${major}-jdk${java_version}"
                    "${registry_org_proj}:${tag_version}"
                    "${registry_org_proj}:${tag_version}-jdk${java_version}"
                )
            else # jre
                base_tag="${registry_org_proj}:${major}-jre${java_version}"
                extra_tags=(
                    "${registry_org_proj}:${tag_version}-jre${java_version}"
                )
            fi
            ;;
        temurin)
            if [ "$variant_type" = "jdk" ]; then
                base_tag="${registry_org_proj}:${major}-jdk${java_version}-temurin"
                extra_tags=(
                    "${registry_org_proj}:${tag_version}-jdk${java_version}-temurin"
                )
            else # jre
                base_tag="${registry_org_proj}:${major}-jre${java_version}-temurin"
                extra_tags=(
                    "${registry_org_proj}:${tag_version}-jre${java_version}-temurin"
                )
            fi
            ;;
        *)
            log "ERROR: Unknown base image type: $base_image"
            return 1
            ;;
    esac

    echo "$base_tag"
    for tag in "${extra_tags[@]}"; do
        echo "$tag"
    done
    return 0
}

# ---------- 遍历并构建所有变体 ----------
process_all_variants() {
    local major="$1"
    local tag_version="$2"
    local registry_org_proj="${REGISTRY}/${ORG}/${PROJ}"

    # 查找所有 Dockerfile（支持 jdk8, jdk11, jdk17, jdk21, jdk25 及 jre）
    while IFS= read -r dockerfile; do
        local variant_dir="$(dirname "$dockerfile")"
        local java_dir="$(basename "$(dirname "$variant_dir")")"   # 如 jdk8
        local variant_type="${java_dir}"                           # 保留 jdk/jre 前缀
        local java_version="${java_dir#jdk}"
        java_version="${java_version#jre}"                         # 仅数字
        local base_image="$(basename "$variant_dir")"              # debian-forky 或 temurin

        # 生成标签
        local tag_list
        tag_list="$(generate_tags "$variant_type" "$base_image" "$java_version" "$major" "$tag_version" "$registry_org_proj" || true)"
        if [ -z "$tag_list" ]; then
            log "WARNING: No tags generated for $variant_dir, skipping"
            continue
        fi

        mapfile -t tags_array <<< "$tag_list"
        local base_tag="${tags_array[0]}"
        local extra_tags=("${tags_array[@]:1}")

        build_and_push "$dockerfile" "$variant_dir" "$base_tag" "${extra_tags[@]}"
    done < <(find "$TEMPLATE_BASE/$major" -path "*/jdk*/Dockerfile" -o -path "*/jre*/Dockerfile" 2>/dev/null || true)
}

# ---------- 主函数 ----------
main() {
    validate_input "$@"
    process_all_variants "$MAJOR" "$TAG_VERSION"
    log "Completed $MAJOR ($FULL_VERSION)"
}

main "$@"
