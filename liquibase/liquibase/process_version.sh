#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='liquibase'
readonly PROJ='liquibase'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"
readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"

version="$1"
IFS=. read -r major_ver minor_ver patch_ver <<< "$version"
ver_num=$((10#$major_ver * 1000000 +
           10#$minor_ver * 1000 +
           10#$patch_ver))

declare -ar VERSION_TAGS=(
    #"latest"
    "$version-alpine"
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
    local context_url
    mkdir -p $context_base

    if [ "$ver_num" -le 5000002 ]; then
	context_url="https://github.com/liquibase/docker.git"
	context="$context_base"
    else
	context_url="https://github.com/liquibase/liquibase.git"
	context="$context_base/docker"
    fi
    git clone -b "v$version" --depth 1 "$context_url" "$context_base"

    "$RESOURCES/dockerfile-maker.sh" "$context/Dockerfile.alpine"
}

# build_variant $variant $context
build_variant()
{
    local variant="$1"
    local context_base="$2"
    local context
    local targets=()
    local tags=${VARIANTS["$variant"]}
    if [ "$ver_num" -le 5000002 ]; then
        context="$context_base"
    else
        context="$context_base/docker"
    fi
    for tag in ${tags[@]}; do
        targets+=("$IMAGE:$tag" "$PROJ:$tag")
    done
    docker_build "$context/Dockerfile.alpine" "${targets[*]}" "$context"
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
