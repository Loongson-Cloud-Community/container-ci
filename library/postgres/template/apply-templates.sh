#!/usr/bin/env bash
set -Eeuo pipefail

readonly ALPINE_VERSION_VARIANTS=(
	'3.21'
	'3.22'
    '3.23'
)

generate_alpine(){
	local postgres_version=$1
	# 1. 从 alpine-versions.json 中读取信息
    local info=$(jq -cr ".\"$postgres_version\"" alpine-versions.json)
	for alpine_version in ${ALPINE_VERSION_VARIANTS[@]}; do
		local build_dir="${postgres_version}/alpine${alpine_version}"
		mkdir -p $build_dir
		echo $info | jinja2 -D alpine_version=$alpine_version Dockerfile-alpine.template - > "${build_dir}/Dockerfile"
		local tags="$postgres_version-alpine$alpine_version"
		jinja2 -D tags=$tags Makefile.template > "${build_dir}/Makefile"
        cp docker-ensure-initdb.sh $build_dir/
        cp docker-entrypoint.sh $build_dir/
	done
}

main() {
    local postgres_version=$1
    generate_alpine "$postgres_version"
}

main "$1"

