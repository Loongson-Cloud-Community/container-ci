#!/bin/bash

# Usage: process_version.sh $version

set -eo pipefail
set -x

source "$(dirname $0)/lib.sh"

readonly ORG='kubernetes'
readonly PROJ='kubernetes'
readonly ARCH='loong64'
readonly REGISTRY='lcr.loongnix.cn'

readonly RESOURCES="resources"


version="$1"

validata_version()
{
    # validate version
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$  ]] || {
        log ERROR "Invalid version format: $1. Expected format: X.Y.Z"
        exit 1
    }
}

# Prepare $version
prepare()
{
    local version="$1"
    log INFO "Preparing version $version"
    validata_version "$version"

    mkdir -p $RESOURCES
    rm -rf $RESOURCES/$PROJ-$version

    pushd "$RESOURCES"
    git clone -b v$version --depth=1 https://github.com/$ORG/$PROJ $PROJ-$version

    patch_dir="patches"
    # Patch
    pushd $PROJ-$version
    git apply --check ../../$patch_dir/0003-patch-for-scripts.patch
    git apply ../../$patch_dir/0003-patch-for-scripts.patch
    git add .
    git commit -m "patch for scripts"

    git tag -f "v$version"
    popd

    popd
}

build()
{
    pushd $RESOURCES/$PROJ-${version#v}

    FORCE_HOST_GO=true KUBE_BUILD_CONFORMANCE=n KUBE_RELEASE_RUN_TESTS=n \
    KUBE_BUILD_PLATFORMS=linux/loong64 \
    KUBE_BASE_IMAGE_REGISTRY=lcr.loongnix.cn/kubernetes-build-image \
    make quick-release

    popd
}

containers=(
kube-apiserver
kube-controller-manager
kube-proxy
kube-scheduler
)

upload()
{
    version="v$version"
    pushd $RESOURCES/$PROJ-${version#v}
    for container in ${containers[@]};
    do
        docker load -i _output/release-images/loong64/$container.tar
        docker tag registry.k8s.io/$container-loong64:$version lcr.loongnix.cn/kubernetes/$container:$version
        docker push lcr.loongnix.cn/kubernetes/$container:$version
        docker rmi registry.k8s.io/$container-loong64:$version
    done
    popd
}

main()
{
    prepare "$version"
    build "$version"
    upload "$version"
}

main
