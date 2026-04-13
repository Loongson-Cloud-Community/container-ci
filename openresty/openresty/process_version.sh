#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='openresty'
readonly PROJ='openresty'
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
	cmd+=" --build-arg RESTY_J=$(nproc)"
    cmd+=" -f $dockerfile"

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
    local DOCKER_REPO="docker-repo"
    local DOCKER_REPO_URL="https://github.com/openresty/docker-openresty.git"

    log INFO "Preparing version $version"
    # 取最新的标签
    DOCKER_REPO_TAG=$(git ls-remote --tags "$DOCKER_REPO_URL" | \
             awk -F'/' '{print $3}' | \
             grep -E "^${version}(-[0-9]+)?$" | \
             sort -V | \
             tail -n 1)

    pushd $RESOURCES

    mkdir -p $context
    if [ -d $DOCKER_REPO ]; then rm -rf $DOCKER_REPO; fi
    git clone -b $DOCKER_REPO_TAG --depth 1 "https://github.com/openresty/docker-openresty.git" "$DOCKER_REPO"
    cp -r $DOCKER_REPO/alpine/* $DOCKER_REPO/nginx.conf $DOCKER_REPO/nginx.vh.default.conf $context
    ./dockerfile-maker.sh $version
    
    popd
}

# build_variant $variant $context
build_variant()
{
    local variant="$1"
    local context="$2"
    local dockerfiles=("Dockerfile" "Dockerfile.fat")
    
    for dockerfile in "${dockerfiles[@]}"; do
	if [ "$dockerfile" = "Dockerfile.fat" ]; then
	    local suffix="alpine-fat"
	else
	    local suffix="alpine"
	fi
	local targets=()
        local tags=${VARIANTS["$variant"]}
        for tag in ${tags[@]}; do
            targets+=("$IMAGE:$tag-$suffix" "$PROJ:$tag-$suffix")
        done
        docker_build "$context/$dockerfile" "${targets[*]}" "$context"
    done
}

build()
{
    build_variant 'version' "$CONTEXT_PREFIX/$version"
}

upload()
{
    for variant in ${!VARIANTS[@]}; do
        local tags="${VARIANTS[$variant]}"
	local suffixes=("alpine" "alpine-fat")
        for tag in ${tags[@]}; do
	    for suffix in "${suffix[@]}"; do
                docker push $IMAGE:$tag-$suffix
	    done
        done
    done
}

clean()
{
    local context=$version
    rm -rf "$RESOURCES/docker-repo"
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
