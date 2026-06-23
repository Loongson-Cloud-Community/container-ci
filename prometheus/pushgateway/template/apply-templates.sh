#!/bin/bash

set -e;

VERSION=$1
org='prometheus'
proj='pushgateway'

busybox_apply_single() {
    local pushgateway_version=${VERSION}

    local build_dir="${pushgateway_version}/busybox"
    rm -rf $build_dir
    mkdir -p ${build_dir}
    jinja2 -D pushgateway_version=$pushgateway_version templates/busybox-Dockerfile.template > $build_dir/Dockerfile
    local tags="${pushgateway_version}-busybox"
    jinja2 "templates/Makefile.template" -D tags=$tags >"${build_dir}/Makefile"
}

distroless_apply_single() {
    local pushgateway_version=${VERSION}
    local build_dir="${pushgateway_version}/distroless"
    rm -rf $build_dir
    mkdir -p ${build_dir}
    jinja2 -D pushgateway_version=$pushgateway_version templates/distroless-Dockefile.template > $build_dir/Dockerfile
    local tags="${pushgateway_version}-distroless"
    jinja2 "templates/Makefile.template" -D tags=$tags >"${build_dir}/Makefile"
}

main() {
    busybox_apply_single
    distroless_apply_single
}

main
