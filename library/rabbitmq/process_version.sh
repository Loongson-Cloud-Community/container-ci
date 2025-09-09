#!/bin/bash

# Usage: process_version.sh $version

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly ORG='library'
readonly PROJ='rabbitmq'
readonly ARCH='loong64'
readonly REGISTRY='lcr.loongnix.cn'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"

readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"

readonly ALPINE_VERSION="3.21"
readonly DEBIAN_VERSION='trixie'

version="$1"

declare -ar ALPINE_TAGS=(
    "alpine"
    "$version-alpine"
)

declare -ar DEBIAN_TAGS=(
    "latest"
    "$version"
)

declare -ar ALPINE_MANAGEMENT_TAGS=(
    "alpine-management"
    "$version-alpine-management"
)

declare -ar DEBIAN_MANAGEMENT_TAGS=(
    "management"
    "$version-management"
)

declare -ar DEBIAN_SLIM_TAGS=(
    "$version-slim"
    "$version-$DEBIAN_VERSION-slim"
)

declare -Ar VARIANTS=(
    ['alpine']="${ALPINE_TAGS[@]}"
    ['debian']="${DEBIAN_TAGS[@]}"
    ['alpine-management']="${ALPINE_MANAGEMENT_TAGS[@]}"
    ['debian-management']="${DEBIAN_MANAGEMENT_TAGS[@]}"
)

# docker_build $Dockerfile $targets $context
docker_build() {
    local dockerfile="$1"
    local targets="$2"
    local context="$3"

    local cmd="docker build"
    cmd+=" -f $dockerfile"
    cmd+=" --build-arg https_proxy=$https_proxy"
    cmd+=" --build-arg http_proxy=$http_proxy"

    local target_str=""
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

    ./update.sh $version
    popd
}

# build_variant alpine-slim context
build_variant()
{
    local variant="$1"
    local context="$2"
    local targets=()
    local tags=${VARIANTS["$variant"]}
    for tag in ${tags[@]}; do
    # 同时构建 lcr.loongnix./x/y:tag 和 y:tag 以解决存在镜像依赖的情况
        targets+=("$IMAGE:$tag" "$PROJ:$tag")
    done
    docker_build "$context/Dockerfile" "${targets[*]}" "$context"
}

build()
{
    build_variant "alpine" "$CONTEXT_PREFIX/$version/alpine"
    build_variant "debian" "$CONTEXT_PREFIX/$version/debian"
    build_variant "alpine-management" "$CONTEXT_PREFIX/$version/alpine/management"
    build_variant "debian-management" "$CONTEXT_PREFIX/$version/debian/management"
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

main()
{
    local version="$1"
    prepare "$version"
    build "$version"
    upload "$version"
}

main "$1"
