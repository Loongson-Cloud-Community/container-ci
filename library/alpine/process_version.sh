#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='alpine'

version="$1"
MINOR_VERSION="${version%.*}"

# Prepare $version
prepare()
{

    log INFO "Preparing version $version"


    pushd template > /dev/null || {
        log ERROR "Failed to enter template directory: $SOURCES_DIR"
        exit 1
    }

    ./versions.sh "$version" || {
        log ERROR "${template_dir}/versions.py script failed for version: $version"
    }

    ./apply-templates.sh || {
        log ERROR "${template_dir}/apply-templates.sh script failed for version: $version"
        exit 1
    }

    popd
}


docker_build(){
	local image="${REGISTRY}/${ORG}/${PROJ}:${MINOR_VERSION}"


	log INFO "Building Docker image: $image"

	local build_dir="template/${MINOR_VERSION}"

	make image -C $build_dir

	log INFO "Successfully built image: $image"

}

docker_push(){
	local build_dir="template/${MINOR_VERSION}"
	make push -C $build_dir
}


process()
{
    prepare $version
    docker_build $version
    docker_push $version
}

process $1

