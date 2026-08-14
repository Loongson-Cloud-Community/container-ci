#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='nacos'
readonly PROJ='nacos-server'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"
readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"

version="$1"


declare -ar VERSION_TAGS=(
    #"latest"
    "$version"
)

declare -Ar VARIANTS=(
    ['version']="${VERSION_TAGS[@]}"
)

# docker_build $Dockerfile $targets $context
docker_build() {
    local dockerfile="$1"
    local targets="$2"
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
    log INFO "Preparing version $version"

    local context_base="$RESOURCES/$version"
    mkdir -p $context_base

    git clone -b "$version" --depth 1 https://github.com/nacos-group/nacos-docker.git "$context_base"
    cp "$RESOURCES/Dockerfile.template" "$context_base/build/Dockerfile"
    sed -i "s/__NACOS_VERSION__/${version#v}/" "$context_base/build/Dockerfile"
}

# build_variant $variant $context
build_variant()
{
    local variant="$1"
    local context_base="$2"
    local context="$context_base/build"
    local targets=()
    local tags=${VARIANTS["$variant"]}
    for tag in ${tags[@]}; do
        targets+=("$IMAGE:$tag" "$PROJ:$tag")
    done
    docker_build "$context/Dockerfile" "${targets[*]}" "$context"
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
    local context=$version
    rm -rf "$RESOURCES/$context"
}

main()
{
    prepare
    build
    upload
    clean
}

main
