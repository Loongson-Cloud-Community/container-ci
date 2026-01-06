#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='qdrant'
readonly IMG_ORG='library'
readonly PROJ='qdrant'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$IMG_ORG/$PROJ"
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
    context="$version"
    local template_file="Dockerfile.template"
    
    log INFO "Preparing version $version"
    validata_version "$version"

    log INFO "Preparing version $version"
    pushd "$RESOURCES"
    
    # 构建环境
    mkdir -p "$context"
    wget -O $version-src.tar.gz --quiet --show-progress https://github.com/$ORG/$PROJ/archive/refs/tags/v$version.tar.gz
    tar -xzf $version-src.tar.gz -C $context --strip-components=1
   
    ../patch.sh $context

    cp $template_file $context/Dockerfile

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

post_process()
{
    rm -f $RESOURCES/$version-src.tar.gz
    rm -rf $RESOURCES/$context 
}

main()
{
    prepare "$version"
    build "$version"
    #upload "$version"
    post_process
}

main
