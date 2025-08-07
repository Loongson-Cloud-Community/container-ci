#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='golang'

readonly SOURCES_DIR='sources'

readonly DEBIAN_VARIANT='trixie'
readonly ALPINE_VARIANT='alpine3.21'

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

alpine_images=(
    "$image_name:alpine"
    "$image_name:$version-alpine"
    "$image_name:$orig_version-alpine"
    "$image_name:$version-$ALPINE_VARIANT"
    "$image_name:$orig_version-$ALPINE_VARIANT"
)

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

    pushd "$SOURCES_DIR"/"$version"/"${DEBIAN_VARIANT}"
    docker_build 'Dockerfile' '.' "${debian_images[@]}"
    popd


    pushd "$SOURCES_DIR"/"$version"/"$ALPINE_VARIANT"
    docker_build 'Dockerfile' '.' "${alpine_images[@]}"
    popd

    log INFO "Successfully built image: $image"
}

# Upload $version
upload()
{
    #log WARN "Upload function not implemented (would push: $image)"
    log INFO "Push image: $image_name"
    for image in ${debian_images[@]} ${alpine_images[@]}; do
        docker push $image
    done
}

main()
{
    prepare $version
    build $version
    upload $version
}

main "$@"
