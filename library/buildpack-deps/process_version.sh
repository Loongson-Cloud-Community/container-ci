#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='buildpack-deps'

readonly SOURCES_DIR='sources'
readonly BASEOS='debian'

version="$1"

### 配置容器名称
readonly image_name="${REGISTRY}/${ORG}/${PROJ}"
readonly debian_variant="$version"

declare -a major_images=(
    "$PROJ:$debian_variant"
    "$image_name:$debian_variant"
)

declare -a scm_images=(
    "$PROJ:$debian_variant-scm"
    "$image_name:$debian_variant-scm"
)

declare -a curl_images=(
    "$PROJ:$debian_variant-curl"
    "$image_name:$debian_variant-curl"
)
### 配置容器名称 END

# Prepare $version
prepare()
{
    
    local version=$1
    log INFO "Preparing version $version"

    ## validate version
    #[[ "$1" =~ ^[0-9]+\.[0-9]+$  ]] || {
    #    log ERROR "Invalid version format: $1. Expected format: X.Y"
    #    exit 1
    #}

    pushd "$SOURCES_DIR" > /dev/null || {
        log ERROR "Failed to enter template directory: $SOURCES_DIR"
        exit 1
    }

    #mkdir -p "$version"

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
    
    # build curl
    pushd "$SOURCES_DIR"/"$BASEOS"/"$debian_variant/curl"
    docker_build 'Dockerfile' '.' "${curl_images[@]}"
    popd

    # build scm
    pushd "$SOURCES_DIR"/"$BASEOS"/"$debian_variant/scm"
    docker_build 'Dockerfile' '.' "${scm_images[@]}"
    popd

    # build trixie
    pushd "$SOURCES_DIR"/"$BASEOS"/"$debian_variant"
    docker_build 'Dockerfile' '.' "${major_images[@]}"
    popd

    log INFO "Successfully built image: $image"
}

# Upload $version
upload()
{
    #log WARN "Upload function not implemented (would push: $image)"
    log INFO "Push image: $image_name"
    for image in ${major_images[@]} ${scm_images[@]} ${curl_images[@]}; do
        docker push $image
    done
}

main()
{
    version=$1
    prepare $version
    build $version
    upload $version
}

main "$@"
