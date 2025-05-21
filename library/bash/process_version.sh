#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='bash'

readonly SOURCES_DIR='sources'

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

# Build $vesion
build()
{
    local version="$1"
    local image="${REGISTRY}/${ORG}/${PROJ}:${version}"

    log INFO "Building Docker image: $image"

    pushd $SOURCES_DIR/$version

    docker build \
        --build-arg "http_proxy=${HTTP_PROXY:-}" \
        --build-arg "https_proxy=${HTTPS_PROXY:-}" \
        -t $image .
    
    popd

    log INFO "Successfully built image: $image"
}

# Upload $version
upload()
{
    local image="${REGISTRY}/${ORG}/${PROJ}:${version}"
    #log WARN "Upload function not implemented (would push: $image)"
    log INFO "Push image: $image"
    docker push $image
}

process()
{
    version=$1
    prepare $version
    build $version
    upload $version
}

process $1
