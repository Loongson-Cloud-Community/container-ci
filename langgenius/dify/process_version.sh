#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='langgenius'
readonly PROJ='dify'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"
readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"

version="$1"


declare -ar VERSION_TAGS=(
    #"latest"
    "$version"
    #"$version-cpuv1"
)

declare -Ar VARIANTS=(
    ['version']="${VERSION_TAGS[@]}"
)

# docker_build $Dockerfile $targets $context
docker_build() {
    local dockerfile="$1"
    local -a targets=("${!2}")
    local context="$3"

    local cmd="docker build"
    cmd+=" -f $dockerfile"

    for target in ${targets[@]}; do
        cmd+=" -t $target"
    done
    cmd+=" $context"

    log INFO "$cmd"
    $cmd
}

validata_version()
{
    # validate version
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$  ]] || {
        log ERROR "Invalid version format: $1. Expected format: X.Y.Z"
        exit 1
    }
}

# Prepare $version
prepare()
{
    local version="$1"
    log INFO "Preparing version $version"
    validata_version "$version"

    pushd "$RESOURCES"
    wget -O $version-src.tar.gz --quiet --show-progress https://github.com/$ORG/$PROJ/archive/refs/tags/$version.tar.gz
    ./update.sh "$version" || {
        log ERROR "update.sh script failed for version: $version"
        exit 1
    }
    
    ../patch.sh "$version" || {
        log ERROR "patch.sh script failed for version: $version"
        exit 1
    }
    popd
}

# build a single component
build_component()
{
    local component="$1"
    local base_context="$2"
    local variant="$3"

    local context="$base_context/$component"
    local dockerfile="$context/Dockerfile"

    local -a targets=()
    local tags=(${VARIANTS["$variant"]})
    for tag in "${tags[@]}"; do
        targets+=("$IMAGE-$component:$tag" "$PROJ-$component:$tag")
    done

    docker_build "$dockerfile" targets[@] "$context"
}

# build_variant alpine-slim
build_variant()
{
    local variant="$1"
    local base_context="$2"

    local components=("web" "api")
    for comp in "${components[@]}"; do
	build_component "$comp" "$base_context" "$variant"
    done
}

build()
{
    build_variant 'version' "$CONTEXT_PREFIX/$version"
}

upload()
{
    for variant in ${!VARIANTS[@]}; do
        local tags="${VARIANTS[$variant]}"
        for tag in ${tags[@]}; do
            docker push $IMAGE:$tag
        done
    done
}

clean()
{
    rm -f "$version-src.tar.gz"
    rm -rf "$CONTEXT_PREFIX/$version"
}

main()
{
    prepare "$version"
    build
    #upload
    clean
}

main
