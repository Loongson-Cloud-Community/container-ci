#!/usr/bin/env bash
set -Eeuo pipefail

readonly ALPINE_VERSION_VARIANTS=(
	'3.21'
	'3.22'
)

readonly DEBIAN_VERSION_VARIANTS=(
	'trixie'
)

generate_alpine(){
	local rust_version=$1
	local info=$(jq -cr ".\"$rust_version\"" versions.json)
	for alpine_version in ${ALPINE_VERSION_VARIANTS[@]}; do
		local build_dir="${rust_version}/alpine${alpine_version}"
		mkdir -p $build_dir
		echo $info | jinja2 -D alpine_version=$alpine_version -D rust_version=$rust_version Dockerfile-alpine.template - > "${build_dir}/Dockerfile"
		local tags="$rust_version-alpine$alpine_version"
		jinja2 -D tags=$tags Makefile.template > "${build_dir}/Makefile"
	done
}

generate_slim(){
    local rust_version=$1
    local info=$(jq -cr ".\"$rust_version\"" versions.json)
    for debian_version in ${DEBIAN_VERSION_VARIANTS[@]}; do
        local build_dir="${rust_version}/${debian_version}/slim"
        mkdir -p $build_dir
        echo $info | jinja2 -D debian_version=$debian_version -D rust_version=$rust_version Dockerfile-slim.template - > "${build_dir}/Dockerfile"
        local tags="$rust_version-${debian_version}-slim"
        jinja2 -D tags=$tags Makefile.template > "${build_dir}/Makefile"
    done
}

generate_debian(){
    local rust_version=$1
    local info=$(jq -cr ".\"$rust_version\"" versions.json)
    for debian_version in ${DEBIAN_VERSION_VARIANTS[@]}; do
        local build_dir="${rust_version}/${debian_version}"
        mkdir -p $build_dir
        echo $info | jinja2 -D debian_version=$debian_version -D rust_version=$rust_version Dockerfile-debian.template - > "${build_dir}/Dockerfile"
        local tags="$rust_version-${debian_version},$rust_version"
        jinja2 -D tags=$tags Makefile.template > "${build_dir}/Makefile"
    done
}


main(){
	generate_alpine "$1"
	generate_slim "$1"
	generate_debian "$1"
}

main $1
