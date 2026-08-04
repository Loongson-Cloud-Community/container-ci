#!/bin/bash

set -Eeuo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='xwiki'
readonly PROJ='xwiki'
readonly ARCH='loong64'
readonly IMAGE="$REGISTRY/$ORG/$PROJ"
readonly RESOURCES="resources"
readonly CONTEXT_PREFIX="$RESOURCES"

version="$1"

databases=("mariadb" "mysql" "postgres")

declare -ar VERSION_TAGS=(
    #"latest"
    "$version"
)

declare -Ar VARIANTS=(
    ['version']="${VERSION_TAGS[@]}"
)

# docker_build $Dockerfile $targets $context
docker_build() {
    local dockerfile="$1"
    local -a targets=("${!2}")
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
    local version="$1"
    local major_ver=$(echo "$version" | cut -d. -f1)
    local context_base=$version
    log INFO "Preparing version $version"
    validata_version "$version"

    pushd "$RESOURCES"

    git clone https://github.com/xwiki/xwiki-docker.git $context_base

    for db in "${databases[@]}"; do
        local context="$context_base/$major_ver/$db-tomcat"
        ./dockerfile-maker.sh "$version" "$context"
    done

    popd
}

# build a single component
build_component()
{
    local db="$1"
    local context="$2"
    local variant="$3"
    local dockerfile="$context/Dockerfile"

    local -a targets=()
    local tags=(${VARIANTS["$variant"]})
    for tag in "${tags[@]}"; do
        targets+=("$IMAGE:$tag-$db-tomcat" "$PROJ:$tag-$db-tomcat")
    done

    docker_build "$dockerfile" targets[@] "$context"
}

# build_variant alpine-slim
build_variant()
{
    local variant="$1"
    local context_base="$2"
    local major_ver=$(echo "$version" | cut -d. -f1)

    for db in "${databases[@]}"; do
	local context="$context_base/$major_ver/$db-tomcat"
	build_component "$db" "$context" "$variant"
    done
}

build()
{
    build_variant 'version' "$CONTEXT_PREFIX/$version"
}

upload()
{
    for db in "${databases[@]}"; do
        for variant in ${!VARIANTS[@]}; do
            local tags="${VARIANTS[$variant]}"
            for tag in ${tags[@]}; do
                docker push "$IMAGE:$tag-$db-tomcat"
            done
        done
    done
}

clean()
{
    local context_base=$version
    rm -rf "$CONTEXT_PREFIX/$context_base"
}

main()
{
    prepare "$version"
    build
    upload
    clean
}

main
