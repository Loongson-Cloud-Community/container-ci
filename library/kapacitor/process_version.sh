#!/bin/bash

set -Eeuo pipefail
source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='kapacitor'
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
    log INFO "Preparing version $version"

    pushd $RESOURCES
    local context=$version
    mkdir -p $context

    [ ! -d influxdata-docker ] && \
        git clone https://github.com/influxdata/influxdata-docker.git
    cp -r "influxdata-docker/kapacitor/${version%.*}/alpine/"* $context
    chmod +x $context/*.sh

    ./dockerfile-maker.sh "$version"
    popd

}

# build_variant $variant $context
build_variant()
{
    local variant="$1"
    local context="$2"
    local targets=()
    local suffix="alpine"
    local tags=${VARIANTS["$variant"]}
    for tag in ${tags[@]}; do
	targets+=("$IMAGE:$tag-$suffix" "$PROJ:$tag-$suffix")
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
            docker push $IMAGE:$tag-alpine
        done
    done
}

clean()
{
    local context=$version
    rm -rf "$RESOURCES/$context" "$RESOURCES/influxdata-docker"
}

main()
{
    prepare
    build
    upload
    clean
}

main
