#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='ruby'

# Prepare $version
prepare()
{

    local version="$1"
    log INFO "Preparing version $version"


    pushd template > /dev/null || {
        log ERROR "Failed to enter template directory: $SOURCES_DIR"
        exit 1
    }

    ./versions.sh "$version" || {
        log ERROR "${template_dir}/versions.sh script failed for version: $version"
    }

    ./apply-templates.sh "$version" || {
        log ERROR "${template_dir}/apply-templates.sh script failed for version: $version"
        exit 1
    }

	./apply-templates-makefile.sh "$version" || {
        log ERROR "${template_dir}/apply-templates-makefile.sh script failed for version: $version"
        exit 1
    }

    popd
}

make_image_with_retry(){
	local build_dir="$1"
	for ((i=1;i<=10;i++)); do
		log INFO "第$i次构建 $build_dir"
      	if make image -C $build_dir; then
         	return
      	fi
	done
}

docker_build(){
    local version="$1"
    local image="${REGISTRY}/${ORG}/${PROJ}:${version}"
    log INFO "Building Docker image: $image"

	# 获取到所有的 dockerfile
	local dockerfiles=$(find ./template/$version -name 'Dockerfile')

	for dockerfile in $dockerfiles; do
		local build_dir=$(dirname $dockerfile)
		make_image_with_retry "$build_dir"
	done

	log INFO "Successfully built image: $image"

}

docker_push(){
    local version="$1"

	# 获取到所有的 dockerfile
	local dockerfiles=$(find ./template/$version -name 'Dockerfile')

	for dockerfile in $dockerfiles; do
		local build_dir=$(dirname $dockerfile)
		make push -C $build_dir
	done
}

process()
{
    version=$1
    prepare $version
    docker_build $version
    docker_push $version
}

process $1

