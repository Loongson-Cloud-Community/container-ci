#!/bin/bash

set -e;

VERSION=$1

busybox_apply_single() {
    local prometheus_version=${VERSION}

    local build_dir="${prometheus_version}/busybox"
    rm -rf $build_dir
    mkdir -p ${build_dir}
    jinja2 -D prometheus_version=$prometheus_version templates/busybox-Dockerfile.template > $build_dir/Dockerfile
    local tags="${prometheus_version}-busybox"
    jinja2 "templates/Makefile.template" -D tags=$tags >"${build_dir}/Makefile"
}

distroless_apply_single() {
    local prometheus_version=${VERSION}
    local build_dir="${prometheus_version}/distroless"
    rm -rf $build_dir
    mkdir -p ${build_dir}
    jinja2 -D prometheus_version=$prometheus_version templates/distroless-Dockefile.template > $build_dir/Dockerfile
    local tags="${prometheus_version}-distroless"
    jinja2 "templates/Makefile.template" -D tags=$tags >"${build_dir}/Makefile"
}

main() {
    busybox_apply_single
    distroless_apply_single
}

main
