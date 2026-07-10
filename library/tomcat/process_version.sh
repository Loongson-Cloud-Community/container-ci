#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="tomcat"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"
TEMPLATE_BASE="${SCRIPT_DIR}/template"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
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
    docker build --network host -t "$base_tag" -f "$dockerfile" "$build_context" || {
        log "ERROR: docker build failed for $base_tag"
        return 1
    }

    for tag in "${extra_tags[@]}"; do
        docker tag "$base_tag" "$tag" || {
            log "ERROR: docker tag failed for $tag"
            return 1
        }
        log "Tagged $base_tag as $tag"
    done

    docker push "$base_tag" || {
        log "ERROR: docker push failed for $base_tag"
        return 1
    }
    for tag in "${extra_tags[@]}"; do
        docker push "$tag" || {
            log "ERROR: docker push failed for $tag"
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

    # 4. 默认标签（不带 Java 版本），指向当前构建版本（会被后续覆盖，保留最高版本）
    extra_tags+=(
        "${registry_org_proj}:${major}"
        "${registry_org_proj}:${tag_version}"
    )

    echo "$base_tag"
    for tag in "${extra_tags[@]}"; do
        echo "$tag"
    done
    return 0
}

process_all_variants() {
    local major="$1"
    local tag_version="$2"
    local registry_org_proj="${REGISTRY}/${ORG}/${PROJ}"

    # 查找所有 jdk*/temurin 和 jre*/temurin Dockerfile
    while IFS= read -r dockerfile; do
        local variant_dir="$(dirname "$dockerfile")"
        local java_dir="$(basename "$(dirname "$variant_dir")")"   # 如 jdk8
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
            continue
        fi

        local base_image="$(basename "$variant_dir")"              # 应为 temurin
        if [[ "$base_image" != "temurin" ]]; then
            log "Skipping non-temurin variant: $variant_dir"
            continue
        fi

        local tag_list
        tag_list="$(generate_tags "$variant_type" "$java_version" "$major" "$tag_version" "$registry_org_proj")" || {
            log "WARNING: Failed to generate tags for $variant_dir"
            continue
        }
        if [ -z "$tag_list" ]; then
            log "WARNING: No tags generated for $variant_dir, skipping"
            continue
        fi

        mapfile -t tags_array <<< "$tag_list"
        local base_tag="${tags_array[0]}"
        local extra_tags=("${tags_array[@]:1}")

        build_and_push "$dockerfile" "$variant_dir" "$base_tag" "${extra_tags[@]}" || {
            log "WARNING: Build failed for $variant_dir, but continuing"
        }
    done < <(find "$TEMPLATE_BASE/$major" -path "*/jdk*/temurin/Dockerfile" -o -path "*/jre*/temurin/Dockerfile" 2>/dev/null || true)
}

main() {
    validate_input "$@"
    process_all_variants "$MAJOR" "$TAG_VERSION"
    log "Completed $MAJOR ($FULL_VERSION)"
}

main "$@"
