#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='kubernetes-csi'
readonly IMAGENAME1='nfs-csi-loong64'
readonly IMAGENAME2='nfsplugin'
readonly PROJ='csi-driver-nfs'
readonly ARCH='loong64'
readonly IMAGE1="$REGISTRY/$ORG/$IMAGENAME1"
readonly IMAGE2="$REGISTRY/$ORG/$IMAGENAME2"
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
    local cmd="docker build "
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
    local context="$version"
     
    log INFO "Preparing version $version"

    pushd "$RESOURCES"
    mkdir -p "$context"
    cp "Dockerfile.template" "$context/Dockerfile"
    local bin="nfsplugin"
    if [ ! -f "$bin"  ]; then
        wget -O "$bin" --quiet --show-progress "https://github.com/loongarch64-releases/$PROJ/releases/download/$version/$bin"
    fi
    chmod +x "$bin"
    mv "$bin" "$context/"
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
        targets+=("$IMAGE1:$tag" "$IMAGE2:$tag")
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
            docker push $IMAGE1:$tag
            docker push $IMAGE2:$tag
        done
    done
}

clean()
{
    local context=$version
    rm -rf "$CONTEXT_PREFIX/$context"
}

main()
{
    prepare
    build
    upload
    clean
}

main
