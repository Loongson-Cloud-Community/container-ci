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

    # 准备构建环境：其它文件
    cp "go-files-loong64/python-syscalls_loong64.go" "$src/internal/static/python_syscall/syscalls_loong64.go"
    cp "go-files-loong64/nodejs-syscalls_loong64.go" "$src/internal/static/nodejs_syscall/syscalls_loong64.go"
    cp "go-files-loong64/config_default_loong64.go" "$src/internal/static/"
    cp "go-files-loong64/seccomp_syscall_loong64.go" "$src/internal/core/lib/"
    pushd $src
    cp "build/build_amd64.sh" "build/build_loong64.sh"
    sed -i 's/amd64/loong64/g' "build/build_loong64.sh"
    ./build/build_loong64.sh
    
    popd

    mkdir "$context/conf" "$context/dependencies"
    cp "$src/main" "$context"
    cp "$src/env" "$context"
    cp "$src/conf/config.yaml" "$context/conf"
    cp "$src/dependencies/python-requirements.txt" "$context/dependencies"

    rm -rf "$src" 
    rm -f "$version-src.tar.gz"
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
