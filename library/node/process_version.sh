#!/bin/bash

# Usage: process_version.sh $version

set -eo pipefail
set -u
set -x

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='node'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"

readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"

readonly ALPINE_VERSION="3.22"
readonly DEBIAN_VERSION="trixie"

version="$1"
raw_version="${version#v}"

# 提取三种格式
x="$(echo "$raw_version" | cut -d. -f1)"                   # 20
xy="$(echo "$raw_version" | cut -d. -f1-2)"                 # 20.19
xyz="$raw_version"                                          # 20.19.2

echo "X: $x"
echo "X.Y: $xy"
echo "X.Y.Z: $xyz"

declare -ar DEBIAN_TAGS=(
    "$xyz-$DEBIAN_VERSION"
    "$x-$DEBIAN_VERSION"
    "$xy-$DEBIAN_VERSION"
    "$DEBIAN_VERSION"
)

declare -ar ALPINE_TAGS=(
    "$xyz-alpine"
    "$x-alpine"
    "$xy-alpine"
    "$xyz-alpine-$ALPINE_VERSION"
    "$x-alpine-$ALPINE_VERSION"
    "$xy-alpine-$ALPINE_VERSION"
)

declare -ar SLIM_TAGS=(
    "$xyz-$DEBIAN_VERSION-slim"
    "$xy-$DEBIAN_VERSION-slim"
    "$x-$DEBIAN_VERSION-slim"
    "$xyz-slim"
    "$xy-slim"
    "$x-slim"
)

declare -Ar VARIANTS=(
    ['alpine']="${ALPINE_TAGS[@]}"
    ['debian']="${DEBIAN_TAGS[@]}"
    ['slim']="${SLIM_TAGS[@]}"
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

docker_build_new() {
    local dockerfile="$1"
    local targets="$2" # This should ideally be an array, but passed as a space-separated string based on your example
    local context="$3"

    local cmd_base="docker build"
    cmd_base+=" -f $dockerfile"
    cmd_base+=" --build-arg https_proxy=$https_proxy"
    cmd_base+=" --build-arg http_proxy=$http_proxy"

    local build_needed=false
    local tags_to_build=""

    # Convert targets string to an array for easier iteration
    IFS=' ' read -r -a target_array <<< "$targets"

    for target in "${target_array[@]}"; do
	image_id=$(docker images -q "$target")
        if [ -n "$image_id" ]; then
	    echo "??? 没有啊"
            log INFO "Image '$target' already exists locally. Skipping build for this tag."
        else
            log INFO "Image '$target' does not exist locally. Will build."
            tags_to_build+=" -t $target"
            build_needed=true
        fi
    done

    if [ "$build_needed" = true ]; then
        local full_cmd="$cmd_base $tags_to_build $context"
        log INFO "Executing build command: $full_cmd"
        $full_cmd
    else
        log INFO "All specified target images already exist. No build initiated."
    fi
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
    log INFO "Preparing version $version"
    validata_version "$version"

    # 提取主版本号，例如从 v20.19.3 提取出 20
    local major_version
    major_version=$(echo "$version" | sed -E 's/^v?([0-9]+)\..*/\1/')

    pushd "$RESOURCES"

    echo "测试 major_version = $major_version"
    ./update.sh $version alpine3.22
    ./update.sh $version trixie
    ./update.sh $version trixie-slim

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
    docker_build_new "$context/Dockerfile" "${targets[*]}" "$context"
}

build()
{
    version=${version#v}  # 去掉前缀 v
    build_variant 'debian' "$CONTEXT_PREFIX/$version/$DEBIAN_VERSION"
    build_variant 'alpine' "$CONTEXT_PREFIX/$version/alpine$ALPINE_VERSION"
    build_variant 'slim'   "$CONTEXT_PREFIX/$version/$DEBIAN_VERSION-slim"
}

upload()
{
    for variant in ${!VARIANTS[@]}; do
        local tags="${VARIANTS[$variant]}"
	local first_tag=$(echo "$tags" | awk '{print $1}')
	# 先测试镜像
        if ! test_node "$first_tag"; then
            echo "错误：镜像 $IMAGE:$first_tag 测试失败，中止上传流程!" >&2
            exit 1
        fi
        for tag in ${tags[@]}; do
            docker push $IMAGE:$tag
        done
    done
}

is_alpine(){
    local tag=$1
    case "$tag" in
        *alpine*) return 0 ;;
        *)        return 1 ;;
    esac
}

get_shell(){
    local tag=$1
    if is_alpine "$tag"; then
	    echo "sh"
    else
	    echo "bash"
    fi
}

#测试node镜像的基本功能
test_node()
{
    local tag=$1
    local shell=$(get_shell "$tag")
    docker run -it --rm -v $(pwd):/test $IMAGE:$tag $shell /test/test.sh
}

main()
{
    local version="$1"
    prepare "$version"
    build "$version"
    upload "$version"
}

main "$1"
