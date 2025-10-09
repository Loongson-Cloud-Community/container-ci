#!/bin/bash

# usage: process_version.sh 20250521T073957Z

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='nginx'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"

readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES/stable"

readonly ALPINE_VERSION="3.21"

declare -r DEBIAN_CODENAME='forky'

# 1.28.0-1
version="${1%-*}"

declare -ar ALPINE_SLIM_VARIANTS=(
    "$version-alpine-slim"
    "$version-alpine$ALPINE_VERSION-slim"
)

declare -ar ALPINE_VARIANTS=(
    "$version-alpine"
    "$version-alpine$ALPINE_VERSION"
)

declare -ar ALPINE_OTEL_VARIANTS=(
    "$version-alpine-otel"
)

declare -ar ALPINE_PERL_VARIANTS=(
    "$version-alpine-perl"
)

declare -ar DEBIAN_VARIANTS=(
    "latest"
    "$version"
    "$version-$DEBIAN_CODENAME"
)

declare -ar DEBIAN_OTEL_VARIANTS=(
    "otel"
    "$version-otel"
    "$version-$DEBIAN_CODENAME-otel"
)

declare -ar DEBIAN_PERL_VARIANTS=(
    "perl"
    "$version-perl"
    "$version-$DEBIAN_CODENAME-perl"
)

declare -Ar VARIANTS=(
    ["alpine-slim"]="${ALPINE_SLIM_VARIANTS[@]}"
    ["alpine"]="${ALPINE_VARIANTS[@]}"
    ["alpine-otel"]="${ALPINE_OTEL_VARIANTS[@]}"
    ["alpine-perl"]="${ALPINE_PERL_VARIANTS[@]}"
    ["debian"]="${DEBIAN_VARIANTS[@]}"
    ["debian-perl"]="${DEBIAN_PERL_VARIANTS[@]}"
)

#declare -Ar VARIANTS=(
#    ["alpine-slim"]="${ALPINE_SLIM_VARIANTS[@]}"
#    ["alpine"]="${ALPINE_VARIANTS[@]}"
#    ["alpine-otel"]="${ALPINE_OTEL_VARIANTS[@]}"
#    ["alpine-perl"]="${ALPINE_PERL_VARIANTS[@]}"
#    ["debian"]="${DEBIAN_VARIANTS[@]}"
#    ["debian-otel"]="${DEBIAN_OTEL_VARIANTS[@]}"
#    ["debian-perl"]="${DEBIAN_PERL_VARIANTS[@]}"
#)
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
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]$  ]] || {
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

    ./update.sh "$version"
    popd
}

# build_variant alpine-slim
build_variant()
{
    local variant="$1"
    local targets=()
    local tags=${VARIANTS["$variant"]}
    for tag in ${tags[@]}; do
        targets+=("$IMAGE:$tag" "$PROJ:$tag")
    done
    docker_build "$CONTEXT_PREFIX/$variant/Dockerfile" "${targets[*]}" "$CONTEXT_PREFIX/$variant"
}

build()
{
    # 由于存在构建依赖关系，需要手动指定构建顺序
    #for variant in ${!VARIANTS[@]}; do
    #    echo "$variant"
    #    echo "${VARIANTS[$variant]}"
    #done
    
    # 构建 alpine-slim

    build_variant 'alpine-slim'
    build_variant 'alpine'
    build_variant 'alpine-otel'
    build_variant 'alpine-perl'
    build_variant 'debian'
    #build_variant 'debian-otel'
    build_variant 'debian-perl'
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
