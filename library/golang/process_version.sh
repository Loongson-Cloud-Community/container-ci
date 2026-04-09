#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='golang'

readonly SOURCES_DIR='sources'

readonly DEBIAN_VARIANT='forky'
readonly ALPINE_VARIANTS=('alpine3.22' 'alpine3.23')  # 修改1：改为数组

# convert X.Y.X to X.Y
orig_version="$1"
version="${1%.*}"

image_name="${REGISTRY}/${ORG}/${PROJ}"
debian_images=(
    "$image_name:$version"
    "$image_name:$orig_version"
    "$image_name:$version-$DEBIAN_VARIANT"
    "$image_name:$orig_version-$DEBIAN_VARIANT"
)

# 修改2：删除原来的 alpine_images 数组定义，改为动态生成

# Prepare $version
prepare()
{
    
    local version=$1
    log INFO "Preparing version $version"

    # validate version
    [[ "$1" =~ ^[0-9]+\.[0-9]+$  ]] || {
        log ERROR "Invalid version format: $1. Expected format: X.Y"
        exit 1
    }

    pushd "$SOURCES_DIR" > /dev/null || {
        log ERROR "Failed to enter template directory: $SOURCES_DIR"
        exit 1
    }

    mkdir -p "$version"

    ./versions.sh "$version" || {
        log ERROR "version.sh script failed for version: $version"
    }

    ./update.sh "$version" || {
        log ERROR "update.sh script failed for version: $version"
        exit 1
    }

    popd
}

# docker_build $Dockerfile $targets $context
docker_build() {
    local dockerfile="$1"
    local context="$2"
    shift 2
    local targets="$@"

    local cmd="docker build"
    cmd+=" -f $dockerfile"

    local target_str=""
    for target in ${targets[@]}; do
        cmd+=" -t $target"
    done
    cmd+=" $context"

    $cmd
}

# Build $vesion
build()
{
    local version="$1"

    log INFO "Building Docker image: $image"

    # 构建 Debian 版本
    pushd "$SOURCES_DIR"/"$version"/"${DEBIAN_VARIANT}"
    docker_build 'Dockerfile' '.' "${debian_images[@]}"
    popd

    # 修改3：遍历所有 Alpine 版本
    for alpine_variant in "${ALPINE_VARIANTS[@]}"; do
        # 动态生成 Alpine 镜像标签
        local alpine_images=(
            "$image_name:alpine"
            "$image_name:$version-alpine"
            "$image_name:$orig_version-alpine"
            "$image_name:$version-$alpine_variant"
            "$image_name:$orig_version-$alpine_variant"
        )
        
        pushd "$SOURCES_DIR"/"$version"/"$alpine_variant"
        docker_build 'Dockerfile' '.' "${alpine_images[@]}"
        popd
    done

    log INFO "Successfully built image: $image"
}

# Upload $version
upload()
{
    log INFO "Push image: $image_name"
    
    # 推送 Debian 镜像
    for image in ${debian_images[@]}; do
        docker push $image
    done
    
    # 修改4：推送所有 Alpine 版本镜像
    for alpine_variant in "${ALPINE_VARIANTS[@]}"; do
        local alpine_images=(
            "$image_name:alpine"
            "$image_name:$version-alpine"
            "$image_name:$orig_version-alpine"
            "$image_name:$version-$alpine_variant"
            "$image_name:$orig_version-$alpine_variant"
        )
        for image in ${alpine_images[@]}; do
            docker push $image
        done
    done
}

main()
{
    prepare $version
    build $version
    upload $version
}

main "$@"
