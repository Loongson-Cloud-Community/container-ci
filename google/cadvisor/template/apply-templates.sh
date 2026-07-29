#!/bin/bash

set -e

apply_single(){

    local cadvisor_version=$1

    # 生成 Dockerfile
    local build_dir="${cadvisor_version}"
    rm -rf ${build_dir}
    mkdir -p "${build_dir}"
    jinja2 -D cadvisor_version=${cadvisor_version} "templates/Dockerfile.template" > "${build_dir}/Dockerfile"

    # 生成 makefile
    local tags="${cadvisor_version}"
    jinja2 "templates/Makefile.template" -D tags=$tags >"${build_dir}/Makefile"

    # 拷贝 entrypoint healthcheck 脚本
    cp templates/entrypoint.sh templates/healthcheck.sh "${build_dir}/"
}

main() {
    local cadvisor_version="$1"
    apply_single "$cadvisor_version"
}

main "$1"
