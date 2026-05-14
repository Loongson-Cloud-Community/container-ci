#!/bin/bash
set -eo pipefail

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="openjdk"

get_full_version() {
    local version="$1"
    jq -r ".[\"$version\"].version" template/versions.json
}

build_and_push() {
    local major="$1"
    local variant="$2"
    local full_version=$(get_full_version "$major")
    local dockerfile="template/$major/$variant/Dockerfile"
    local image_tag="${REGISTRY}/${ORG}/${PROJ}:${major}-${variant}"
    local full_tag="${REGISTRY}/${ORG}/${PROJ}:${full_version}-${variant}"

    echo "Building $image_tag from $dockerfile"
    docker build -t "$image_tag" -f "$dockerfile" . || exit 1
    docker tag "$image_tag" "$full_tag"
    echo "Pushing $image_tag and $full_tag"
    docker push "$image_tag" || echo "WARNING: push failed for $image_tag, continuing"
    docker push "$full_tag" || echo "WARNING: push failed for $full_tag, continuing"

    if [ "$variant" = "debian-forky" ]; then
        local main_tag="${REGISTRY}/${ORG}/${PROJ}:${major}"
        local full_short_tag="${REGISTRY}/${ORG}/${PROJ}:${full_version}"
        docker tag "$image_tag" "$main_tag" || true
        docker push "$main_tag" || echo "WARNING: push failed for $main_tag"
        docker tag "$image_tag" "$full_short_tag" || true
        docker push "$full_short_tag" || echo "WARNING: push failed for $full_short_tag"
        echo "Pushed main tags: $main_tag, $full_short_tag"

        local jdk_tag="${REGISTRY}/${ORG}/${PROJ}:${major}-jdk"
        local full_jdk_tag="${REGISTRY}/${ORG}/${PROJ}:${full_version}-jdk"
        docker tag "$image_tag" "$jdk_tag" || true
        docker push "$jdk_tag" || echo "WARNING: push failed for $jdk_tag"
        docker tag "$image_tag" "$full_jdk_tag" || true
        docker push "$full_jdk_tag" || echo "WARNING: push failed for $full_jdk_tag"
        echo "Pushed jdk tags: $jdk_tag, $full_jdk_tag"
    elif [ "$variant" = "debian-forky-slim" ]; then
        local slim_tag="${REGISTRY}/${ORG}/${PROJ}:${major}-slim"
        local full_slim_tag="${REGISTRY}/${ORG}/${PROJ}:${full_version}-slim"
        docker tag "$image_tag" "$slim_tag" || true
        docker push "$slim_tag" || echo "WARNING: push failed for $slim_tag"
        docker tag "$image_tag" "$full_slim_tag" || true
        docker push "$full_slim_tag" || echo "WARNING: push failed for $full_slim_tag"
        echo "Pushed slim tags: $slim_tag, $full_slim_tag"
    elif [ "$variant" = "openanolis-23.4" ]; then
        echo "OpenAnolis variant, no additional aliases"
    fi
}

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <major_version>"
        exit 1
    fi
    local major="$1"
    for variant_dir in template/$major/*/; do
        variant=$(basename "$variant_dir")
        build_and_push "$major" "$variant"
    done
}

main "$@"
