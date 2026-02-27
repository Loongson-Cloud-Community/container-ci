#!/bin/bash

set -euo pipefail
set -x

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='erlang'
readonly SRCS='sources'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"

# 29.0.1-rc1
version="$1"

major_version="${version//.*/}"

declare -ar ALPINE_TAGS=(
    "alpine"
    "$version-alpine"
    "$major_version-alpine"
)

declare -ar DEBIAN_TAGS=(
    "latest"
    "$version"
    "$major_version"
)

declare -ar SLIM_TAGS=(
    "slim"
    "$version-slim"
    "$major_version-slim"
)

declare -Ar VARIANTS=(
    ['alpine']="${ALPINE_TAGS[@]}"
    ['debian']="${DEBIAN_TAGS[@]}"
    ['slim']="${SLIM_TAGS[@]}"
)

# Prepare $version
prepare()
{

    log INFO "Preparing version $version"
    
    mkdir -pv $SRCS
    rm -rf $SRCS/docker-erlang-opt
    git clone --depth=1 https://github.com/erlang/docker-erlang-otp $SRCS/docker-erlang-opt

    pushd $SRCS/docker-erlang-opt/$major_version
    for dockerfile in $(find * -name Dockerfile); do
        sed -i '/FROM/s/trixie/forky/g' $dockerfile
    done
    popd
}

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

# build_variant alpine-slim context
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
    CONTEXT_PREFIX=$SRCS/docker-erlang-opt
    build_variant "debian" "$CONTEXT_PREFIX/$major_version"
    build_variant "alpine" "$CONTEXT_PREFIX/$major_version/alpine"
    build_variant "slim" "$CONTEXT_PREFIX/$major_version/slim"
}

upload(){
    for variant in ${!VARIANTS[@]}; do
        local tags="${VARIANTS[$variant]}"
        for tag in ${tags[@]}; do
            docker push $IMAGE:$tag
        done
    done
}

main()
{
    prepare
    build
    upload
}

main

