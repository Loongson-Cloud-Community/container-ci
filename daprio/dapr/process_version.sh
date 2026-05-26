#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='daprio'
readonly PROJS=("daprd" "placement" "operator" "injector" "sentry" "scheduler")
readonly ARCH='loong64'
readonly IMAGE_BASE="$REGISTRY/$ORG"
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
    local proj="$4"
    local cmd="docker build"
    cmd+=" --build-arg PKG_FILES=$proj"
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
    local context="$RESOURCES/$version"

    log INFO "Preparing version $version"

    mkdir -p "$context"
    [ ! -f "$RESOURCES/$version.tar.gz" ] && \
	wget -O "$RESOURCES/$version.tar.gz" --quiet --show-progress "https://github.com/loongarch64-releases/dapr/releases/download/v${version}/dapr_linux_loong64_v${version}.tar.gz"
    tar -xzf "$RESOURCES/$version.tar.gz" -C "$context"
    cp "$RESOURCES/Dockerfile.template" "$context/Dockerfile"

}

# build_variant $variant $context
build_variant()
{
    local variant="$1"
    local context="$2"
    local tags=${VARIANTS["$variant"]}

    for proj in ${PROJS[@]}; do
        local targets=()
        for tag in ${tags[@]}; do
            targets+=("$IMAGE_BASE/$proj:$tag" "$proj:$tag")
	done
        docker_build "$context/Dockerfile" "${targets[*]}" "$context" "$proj"
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
	for proj in ${PROJS[@]}; do
            for tag in ${tags[@]}; do
                docker push $IMAGE_BASE/$proj:$tag
	    done
        done
    done
}

clean()
{
    local context=$version
    rm -rf "$RESOURCES/$context" "$RESOURCES/$version.tar.gz"
}

main()
{
    prepare
    build
    upload
    clean
}

main
