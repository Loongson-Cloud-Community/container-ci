#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='logstash'
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
    local context="$version"

    log INFO "Preparing version $version"

    pushd $RESOURCES
    ./update.sh $version

    # env2yaml基于java时，从elastic/dockerfiles拉取现成的
    git clone -q -b v$version https://github.com/elastic/dockerfiles.git
    if [ -d "dockerfiles/logstash/env2yaml/lib" ]; then
	cp -r "dockerfiles/logstash/." "$context/"
	rm -rf dockerfiles
    else
	# env2yaml基于go时，编译
        local logstash_src="$PROJ-src"
        wget -O "$logstash_src.tar.gz" --quiet --show-progress https://github.com/elastic/logstash/archive/refs/tags/v$version.tar.gz
        mkdir -p $logstash_src
        tar -xzf "$logstash_src.tar.gz" -C "$logstash_src" --strip-components=1
        cp -r "$logstash_src/docker/data/logstash/." "$context/"
	rm -rf dockerfiles "$logstash_src.tar.gz" "$logstash_src"
    fi

    # 根据env2yaml实现方式选择Dockerfile
    if [ -f "$context/env2yaml/env2yaml.go" ]; then
        mv "$context/dockerfile-1" "$context/Dockerfile"
	rm -f "$context/dockerfile-2"
    else
        mv "$context/dockerfile-2" "$context/Dockerfile"
	rm -f "$context/dockerfile-1"
    fi

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
        done
    done
}

main()
{
    prepare
    build
    #upload
}

main
