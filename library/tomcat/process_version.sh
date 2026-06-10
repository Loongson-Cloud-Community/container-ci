#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="tomcat"

PRIMARY_VARIANT="jdk25/debian-forky"
LATEST_MAJOR="11.0"
TEMPLATE_DIR="template"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <major_version>"
    exit 1
fi

version="$1"
versions_json="$TEMPLATE_DIR/versions.json"

full_version=$(jq -r ".[\"$version\"].version" "$versions_json")
if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
    log "ERROR: Cannot find full version for $version"
    exit 1
fi
log "Building Tomcat $version ($full_version)"

variants=$(jq -r ".[\"$version\"].variants[]" "$versions_json")

for variant in $variants; do
    java_variant=$(echo "$variant" | cut -d/ -f1)
    os_variant=$(echo "$variant" | cut -d/ -f2)
    java_version=${java_variant#jdk}

    build_dir="$TEMPLATE_DIR/$version/$variant"
    if [ ! -d "$build_dir" ]; then
        log "WARNING: Directory $build_dir not found, skipping"
        continue
    fi

    image_name="${REGISTRY}/${ORG}/${PROJ}"
    tag_base="${full_version}-${java_variant}-${os_variant}"

    log "Building $image_name:$tag_base from $build_dir"
    docker build --network host -t "${image_name}:${tag_base}" "$build_dir" || {
        log "ERROR: Build failed for variant $variant"
        exit 1
    }
    docker push "${image_name}:${tag_base}"

    aliases=()
    major_minor=$(echo "$full_version" | cut -d. -f1,2)
    major=$(echo "$full_version" | cut -d. -f1)

    aliases+=("${major_minor}-${java_variant}-${os_variant}")
    aliases+=("${major}-${java_variant}-${os_variant}")
    aliases+=("${java_variant}-${os_variant}")
    aliases+=("${full_version}-${java_variant}")
    aliases+=("${major_minor}-${java_variant}")
    aliases+=("${major}-${java_variant}")
    aliases+=("${java_variant}")

    if [ "$variant" = "$PRIMARY_VARIANT" ]; then
        aliases+=("$full_version")
        aliases+=("$major_minor")
        aliases+=("$major")
        if [ "$version" = "$LATEST_MAJOR" ]; then
            aliases+=("latest")
        fi
    fi

    for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
        docker tag "${image_name}:${tag_base}" "${image_name}:${alias}"
        docker push "${image_name}:${alias}"
        log "Pushed alias: ${alias}"
    done
done

log "All variants for version $version done."
