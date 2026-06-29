#!/bin/bash
set -eo pipefail

# 日志函数
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="postfixadmin"

VERSIONS_JSON="template/versions.json"
if [ ! -f "$VERSIONS_JSON" ]; then
    log ERROR "$VERSIONS_JSON not found"
    exit 1
fi

version=$(jq -r 'keys[0]' "$VERSIONS_JSON")
if [ -z "$version" ] || [ "$version" = "null" ]; then
    log ERROR "Failed to parse version from $VERSIONS_JSON"
    exit 1
fi
log INFO "Building postfixadmin version: $version"

variants=("apache" "fpm" "fpm-alpine")
major_minor="${version%.*}"   # 4.0
major="${major_minor%.*}"     # 4

build_and_push() {
    local variant="$1"
    local build_dir="template/$version/$variant"
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local specific_tag="${version}-${variant}"
    
    log INFO "Building $image_name:$specific_tag from $build_dir"
    docker build --timeout 30m -t "${image_name}:${specific_tag}" "$build_dir" || {
        log ERROR "Build failed for $image_name:$specific_tag"
        exit 1
    }
    
    log INFO "Pushing $image_name:$specific_tag"
    docker push "${image_name}:${specific_tag}" || {
        log ERROR "Push failed for $image_name:$specific_tag"
        exit 1
    }
    
    local aliases=()
    case "$variant" in
        apache)
            aliases+=("${major_minor}-apache")
            aliases+=("${major}-apache")
            aliases+=("apache")
            aliases+=("$version")
            aliases+=("$major_minor")
            aliases+=("$major")
            ;;
        fpm)
            aliases+=("${major_minor}-fpm")
            aliases+=("${major}-fpm")
            aliases+=("fpm")
            ;;
        fpm-alpine)
            aliases+=("${major_minor}-fpm-alpine")
            aliases+=("${major}-fpm-alpine")
            aliases+=("fpm-alpine")
            ;;
        *)
            log WARN "Unknown variant $variant, skipping alias generation"
            ;;
    esac
    
    for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
        docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
        docker push "${image_name}:${alias}"
        log INFO "Pushed alias: ${alias}"
    done
}

for variant in "${variants[@]}"; do
    if [ ! -d "template/$version/$variant" ]; then
        log WARN "Directory template/$version/$variant not found, skipping"
        continue
    fi
    build_and_push "$variant"
done

log INFO "All images for version $version processed."
