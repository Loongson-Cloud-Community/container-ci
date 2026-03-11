#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='elasticsearch'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"
readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"

version="${1#v}"

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

## Prepare $version
prepare()
{
    local es_docker_repo="dockerfiles"
    local es_docker_bin="$es_docker_repo/elasticsearch/bin"
    local es_docker_config="$es_docker_repo/elasticsearch/config"
    
    log INFO "Preparing version $version"
    pushd "$RESOURCES"
    
    ./update.sh $version
    local context=$version

    if [ ! -d "$es_docker_repo" ]; then
        git clone --depth 1 --single-branch -b "v$version" "https://github.com/elastic/$es_docker_repo.git"    
    fi

    cp -rf $es_docker_bin $context
    cp -rf $es_docker_config $context
    rm -rf $es_docker_repo

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
            docker rmi -f $IMAGE:$tag
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

