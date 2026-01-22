#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='langgenius'
readonly PROJ='dify-sandbox'
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
    local context="$version"
    local src=$PROJ-$version
    log INFO "Preparing version $version"
    validata_version "$version"

    pushd "$RESOURCES"

    # 准备构建环境：Dockerfile
    wget -O $version-src.tar.gz --quiet --show-progress https://github.com/$ORG/$PROJ/archive/refs/tags/$version.tar.gz
    mkdir $src
    tar -xzf $version-src.tar.gz -C $src --strip-components=1
    ./update.sh "$version" || {
        log ERROR "update.sh script failed for version: $version"
        exit 1
    }
    mkdir -p "$context/conf" "$context/dependencies"
    cp "$src/conf/config.yaml" "$context/conf"
    cp "$src/dependencies/python-requirements.txt" "$context/dependencies"

    wget -O $context/env --quiet --show-progress https://github.com/loongarch64-releases/dify-sandbox/releases/download/$version/env
    wget -O $context/main --quiet --show-progress https://github.com/loongarch64-releases/dify-sandbox/releases/download/$version/main

    rm -rf "$src" "$version-src.tar.gz"
    popd
}

# build_variant alpine-slim
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
