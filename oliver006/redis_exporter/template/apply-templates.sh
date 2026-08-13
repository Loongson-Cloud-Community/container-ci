#!/bin/bash

set -e

apply_single(){

    local redis_exporter_version=$1
    local alpine_version=${2:-3.24}

    # 生成 Dockerfile
    local build_dir="${redis_exporter_version}"
    rm -rf ${build_dir}
    mkdir -p "${build_dir}"
    jinja2 -D redis_exporter_version=${redis_exporter_version} -D alpine_version=${alpine_version} "templates/Dockerfile.template" > "${build_dir}/Dockerfile"

    # 生成 makefile
    local tags="${redis_exporter_version}"
    jinja2 "templates/Makefile.template" -D tags=$tags >"${build_dir}/Makefile"
}

main() {
    local redis_exporter_version="$1"
    apply_single "$redis_exporter_version"
}

main "$1"
