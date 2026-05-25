#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='neo4j'
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
    local context="$version"
    local docker_src="docker-neo4j/docker-image-src"
    local major_ver="$(echo "$version" | cut -d. -f1)"
    if [ "$major_ver" -lt 5 ]; then
	local docker_src_branch=${version%.*}
    else
	local docker_src_branch=$major_ver
    fi

    log INFO "Preparing version $version"
    pushd $RESOURCES

    mkdir -p "$context/local-package"
    ./dockerfile-maker.sh $version

    [ -d docker-neo4j ] && rm -rf docker-neo4j
    git clone "https://github.com/neo4j/docker-neo4j.git" docker-neo4j
    cp $docker_src/$docker_src_branch/coredb/*.sh "$context/local-package"
    cp $docker_src/$docker_src_branch/coredb/*.json "$context/local-package"
    cp $docker_src/common/* "$context/local-package"

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

clean()
{
    local context=$version
    rm -rf "$RESOURCES/$context" "$RESOURCES/docker-neo4j"
}

main()
{
    prepare
    build
    upload
    clean
}

main
