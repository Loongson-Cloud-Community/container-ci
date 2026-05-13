#!/bin/bash

set -e

VERSION=$1

git_clone(){
    git clone --depth=1 --branch v${VERSION} https://github.com/prometheus-operator/prometheus-operator.git prometheus-operator-${VERSION}
}

apply_single() {

    local build_dir=${VERSION}
    rm -rf $build_dir
    mkdir $build_dir
    (
        cd $build_dir
        git_clone
        (
            cd prometheus-operator-${VERSION}
            rm -rf Dockerfile
            cp ../../prometheus-operator-builder.Dockerfile Dockerfile
            docker build -t lcr.loongnix.cn/prometheus-operator/prometheus-operator:${VERSION} .
            docker push lcr.loongnix.cn/prometheus-operator/prometheus-operator:${VERSION}
        )
        rm -rf prometheus-operator-${VERSION}

    )
}

main() {
    apply_single
}

main
