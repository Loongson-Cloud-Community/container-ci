#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='grafana'
readonly PROJ='pyroscope'
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

    local context="$RESOURCES/$version"
    mkdir -p $context

    wget -O "$context/pyroscope" "https://github.com/loongarch64-releases/pyroscope/releases/download/v$version/pyroscope"
    wget -O "$context/profilecli" "https://github.com/loongarch64-releases/pyroscope/releases/download/v$version/profilecli"
    chmod +x "$context/pyroscope" "$context/profilecli"
    curl -sSL -o "$context/pyroscope.yaml" "https://raw.githubusercontent.com/$ORG/$PROJ/v$version/cmd/pyroscope/pyroscope.yaml"
    cp "$RESOURCES/Dockerfile.template" "$context/Dockerfile"
}

# build_variant $variant $context
build_variant()
{
    local variant="$1"
    local context="$2"
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
