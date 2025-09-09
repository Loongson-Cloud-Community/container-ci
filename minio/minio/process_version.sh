#!/bin/bash

# Usage: process_version.sh $version

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='minio'
readonly PROJ='minio'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"

readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"


version="$1"

declare -ar VERSION_TAGS=(
    "latest"
    "$version"
    "$version-cpuv1"
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

# Prepare $version
prepare()
{
    local version="$1"
    log INFO "Preparing version $version"

    pushd "$RESOURCES"

    ./update.sh $version

    popd
}

# build_variant $variant $context
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
    build_variant 'version' "$CONTEXT_PREFIX/$version"
}

upload()
{
    for variant in ${!VARIANTS[@]}; do
        local tags="${VARIANTS[$variant]}"
        for tag in ${tags[@]}; do
            docker push $IMAGE:$tag
	    docker rmi -f $IMAGE:$tag
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
