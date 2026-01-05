#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='redis'

get_template_dir(){
    local version="$1"
    local major_version=$(echo ${version} | cut -d. -f1)
    local template_dir="template-${major_version}"
	echo "${template_dir}"
}

# Prepare $version
prepare()
{
    
    local version="$1"
	local template_dir=$(get_template_dir "${version}")
    log INFO "Preparing version $version"


    pushd "${template_dir}" > /dev/null || {
        log ERROR "Failed to enter template directory: $SOURCES_DIR"
        exit 1
    }

    ./versions.py "$version" || {
        log ERROR "${template_dir}/versions.py script failed for version: $version"
    }

    ./apply-templates.sh || {
        log ERROR "${template_dir}/apply-templates.sh script failed for version: $version"
        exit 1
    }

    popd
}

_create_pr(){

    # 1. 声明并初始化映射
    declare -A os2version=(
        ["alpine"]="alpine3.21"
        ["debian"]="trixie"
    )

    local -r version=$1
    local -r os=$2

    # 参数校验
    if [[ -z "$version" || -z "$os" ]]; then
        echo "Usage: _create_pr <version> <os>"
        return 1
    fi

    # 校验 os 是否在映射中
    if [[ -z "${os2version[$os]}" ]]; then
        echo "Error: Unsupported OS '$os'. Supported: ${!os2version[*]}"
        return 1
    fi

    local -r template_dir=$(get_template_dir "${version}")
    local -r src_dir="${template_dir}/${version}/${os}"
    local -r dst_dir="${ORG}/${PROJ}/$version-${os2version[$os]}"
    local -r branch="${ORG}-${PROJ}-$version-$os-$(printf '%04d' $RANDOM)"

    create_pr "$src_dir" "$dst_dir" "$branch"
}

# Build $vesion
docker_build()
{
    local version="$1"
    local image="${REGISTRY}/${ORG}/${PROJ}:${version}"
	local template_dir=$(get_template_dir "${version}")

    log INFO "Building Docker image: $image"


	local debian_build_dir="${template_dir}/${version}/debian"
	local alpine_build_dir="${template_dir}/${version}/alpine"
	make image -C "${debian_build_dir}"
	make image -C "${alpine_build_dir}"

    log INFO "Successfully built image: $image"
}

# Upload $version
docker_push()
{
    local version="$1"
    local image="${REGISTRY}/${ORG}/${PROJ}:${version}"
	local template_dir=$(get_template_dir "${version}")

    #log WARN "Upload function not implemented (would push: $image)"
    log INFO "Push image: $image"

	local debian_build_dir="${template_dir}/${version}/debian"
	local alpine_build_dir="${template_dir}/${version}/alpine"
	make push -C "${debian_build_dir}"
	make push -C "${alpine_build_dir}"

}

process()
{
    version=$1
    prepare $version
    docker_build $version
    docker_push $version
#	_create_pr "$version" "alpine"
#	_create_pr "$version" "debian"
}

process $1
