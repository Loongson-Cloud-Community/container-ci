#!/bin/bash

set -e

apply_single(){

    local node_exporter_version=$1

    # 生成 Dockerfile
    local build_dir="${node_exporter_version}"
    rm -rf ${build_dir}
    mkdir -p "${build_dir}"
    jinja2 -D node_exporter_version=${node_exporter_version} "templates/Dockerfile.template" > "${build_dir}/Dockerfile"

    # 生成 makefile
    local tags="${node_exporter_version}"
    jinja2 Makefile.template -D tags=$tags >"${build_dir}/Makefile"
}

main() {
    local node_exporter_version="$1"
    apply_single "$node_exporter_version"
}

main "$1"
