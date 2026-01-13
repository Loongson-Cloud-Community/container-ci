#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='langgenius'
readonly PROJ='dify-plugin-daemon'
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

    local target_str=""
    for target in ${targets[@]}; do
        cmd+=" -t $target"
    done
    cmd+=" $context"

    log INFO "$cmd"
    DOCKER_BUILDKIT=0 $cmd
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

    ./update.sh "$version" || {
        log ERROR "update.sh script failed for version: $version"
        exit 1
    }

    popd
}

# build_variant alpine-slim
build_variant()
{
    local variant="$1"
    local context="$2"
    
    local -a dockerfiles=("local.dockerfile" "serverless.dockerfile")
    for dockerfile in "${dockerfiles[@]}"; do
	cp "$context/$dockerfile" "$context/Dockerfile"
       
        local targets=()
        local tags=${VARIANTS["$variant"]}
	for tag in ${tags[@]}; do
	    # 同时构建 local 和 serverless
            local suffix="${dockerfile%.dockerfile}"
            targets+=("$IMAGE:$tag-$suffix" "$PROJ:$tag-$suffix")
        done
        docker_build "$context/Dockerfile" "${targets[*]}" "$context"
    done
}

build()
{
    build_variant 'version' "$CONTEXT_PREFIX/$version"
    rm -f "$CONTEXT_PREFIX/$version/Dockerfile"
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
    #upload "$version"
}

main
