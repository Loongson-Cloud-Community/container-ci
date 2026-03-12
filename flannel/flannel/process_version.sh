#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='flannel'
readonly PROJ='flannel'
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
    local build_args="$4"
    local cmd="docker build"
    cmd+=" -f $dockerfile"
    
    if [ -n "$build_args" ]; then
	for arg in $build_args; do
            cmd+=" --build-arg $arg"
	done
    fi

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
    local context="$version"    
    log INFO "Preparing version $version"
 
    pushd $RESOURCES
    if [ -d "$context" ]; then rm -rf $context; fi
    mkdir -p "$context"
    wget -O "$PROJ-$version.tar.gz" --quiet --show-progress "https://github.com/flannel-io/$PROJ/archive/refs/tags/v$version.tar.gz"
    tar -xzf "$PROJ-$version.tar.gz" -C "$context" --strip-components=1

    cp Dockerfile.template "$context/Dockerfile"
    popd
}

# build_variant $variant $context
build_variant()
{
    local variant="$1"
    local context="$2"
    local targets=()
    local tags=${VARIANTS["$variant"]}
    local build_args="TAG=v$version"

    for tag in ${tags[@]}; do
    # 同时构建 lcr.loongnix./x/y:tag 和 y:tag 以解决存在镜像依赖的情况
        targets+=("$IMAGE:$tag" "$PROJ:$tag")
    done

    docker_build "$context/Dockerfile" "${targets[*]}" "$context" "$build_args"
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
    rm -f "$RESOURCES/$PROJ-$version.tar.gz"
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

