#!/bin/bash

# Usage: process_version.sh $version

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='buildkit'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"

readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"

readonly ALPINE_VERSION="3.22"

version="$1"

declare -ar VERSION_TAGS=(
    "latest"
    "$version"
    "$version-alpine-$ALPINE_VERSION"
)


declare -Ar VARIANTS=(
    ['version']="${VERSION_TAGS[@]}"
)

# docker_build $Dockerfile $targets $context
docker_build() {
    local dockerfile="$1"
    local targets="$2"
    local context="$3"

    local cmd="docker buildx build"
    cmd+=" -f $dockerfile"
    cmd+=" --build-arg https_proxy=$https_proxy"
    cmd+=" --build-arg http_proxy=$http_proxy"
    cmd+=" --load"

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
    # X.Y
    #local VERSION_REGEX='^[0-9]+.[0-9]+$'
    # X.Y.Z
    #local VERSION_REGEX='^[0-9]+\.[0-9]+\.[0-9]+'
    # vX.Y.Z.
    local VERSION_REGEX='^v?[0-9]+\.[0-9]+\.[0-9]+([.-]rc[.-]?[0-9]*)?$'
    [[ "$1" =~ $VERSION_REGEX ]] || {
        log ERROR "Invalid version format: $1. Expected format: X.Y.Z"
        exit 1
    }
}

# Prepare $version
prepare()
{
    local version="$1"
    log INFO "Prepare buildx"
    # 检查buildx是否存在
    if ! command -v docker buildx &> /dev/null; then
        echo "Docker Buildx未安装，开始下载安装..."

        # 创建临时目录
        mkdir -p tmp-buildx && cd tmp-buildx

        #  下载文件（添加错误处理）
        if ! wget -q https://cloud.loongnix.cn/releases/loongarch64/docker/buildx/0.12.0-rc1/buildx-linux-loong64.tar.gz; then
            echo "下载失败，请检查网络或链接有效性"
            exit 1
        fi

        # 解压并安装
        tar -xzf buildx-linux-loong64.tar.gz
        mkdir -p ~/.docker/cli-plugins
        mv bin/buildx/docker-buildx ~/.docker/cli-plugins/docker-buildx
        chmod +x ~/.docker/cli-plugins/docker-buildx

        echo "Buildx安装完成！"
    else
        echo "Docker Buildx已安装，版本：$(docker buildx version)"
    fi
    log INFO "Preparing version $version"
    validata_version "$version"

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

test_variant() {
    local variant="$1"
    local tags=${VARIANTS["$variant"]}

    for tag in ${tags[@]}; do
        echo "🧪 Running test for image $IMAGE:$tag ..."

        # 删除可能存在的旧 builder
        docker buildx rm -f loongson-test || true

        # 创建以该测试镜像为 driver 的 buildx builder
        if ! docker buildx create --name loongson-test \
            --driver docker-container \
            --driver-opt image="$IMAGE:$tag" \
	    --config /etc/buildkit/buildkitd.toml > /dev/null; then
            echo "❌ Failed to create buildx with image $IMAGE:$tag"
            return 1
        fi

        # 设为当前 builder
        docker buildx use loongson-test

        # 执行测试构建
        if ! docker buildx build -t test-output -f Dockerfile.test .; then
            echo "❌ Test build failed for $IMAGE:$tag"
            docker buildx rm -f loongson-test
            return 1
        fi

        echo "✅ Test passed for $IMAGE:$tag"
        docker buildx rm -f loongson-test
	break
    done
    return 0
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
    local version="$1"
    prepare "$version"
    build "$version"
    if test_variant 'version'; then
        upload "$version"
    else
        echo "🛑 Build test failed. Skipping upload for $version."
        exit 1
    fi
}

main "$1"
