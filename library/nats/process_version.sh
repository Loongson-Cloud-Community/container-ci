#!/bin/bash

# Usage: process_version.sh $version

set -eo pipefail
set -u

source "$(dirname $0)/lib.sh"

readonly ORG='library'
readonly PROJ='nats'
readonly ARCH='loong64'
readonly REGISTRY='lcr.loongnix.cn'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"

readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"

readonly ALPINE_VERSION="3.22"
readonly DEBIAN_VERSION='trixie'

version="${1#v}"

declare -ar ALPINE_TAGS=(
    "latest"
    "$version"
    "alpine"
    "$version-alpine"
    "$version-alpine$ALPINE_VERSION"
)

declare -ar DEBIAN_TAGS=(
    "latest"
    "$version"
    "$version-$DEBIAN_VERSION"
)

declare -ar DEBIAN_SLIM_TAGS=(
    "$version-slim"
    "$version-$DEBIAN_VERSION-slim"
)

declare -Ar VARIANTS=(
    ['alpine']="${ALPINE_TAGS[@]}"
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
    #cmd+=" --build-arg no_proxy=$no_proxy"
    cmd+=" --network=host"

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
    #validata_version "$version"

    pushd "$RESOURCES"

    ./update.sh $version

    popd
}

# build_variant alpine-slim
build_variant()
{
    local variant="$1"
    local targets=()
    local tags=${VARIANTS["$variant"]}
    for tag in ${tags[@]}; do
    # 同时构建 lcr.loongnix./x/y:tag 和 y:tag 以解决存在镜像依赖的情况
        targets+=("$IMAGE:$tag" "$PROJ:$tag")
    done
    docker_build "$CONTEXT_PREFIX/$version/$variant/Dockerfile" "${targets[*]}" "$CONTEXT_PREFIX/$version/$variant"
}

build()
{
    for variant in ${!VARIANTS[@]}; do
        build_variant "$variant"
    done
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
    prepare "$version"
    build "$version"
    upload "$version"
}

main "$1"
