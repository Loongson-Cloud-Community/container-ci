#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='postgres'

prepare()
{
    local version="$1"               # 例如 18.3
    log INFO "Preparing version $version"

    pushd template > /dev/null || {
        log ERROR "Failed to enter template directory"
        exit 1
    }

    local major="${version%%.*}"     # 例如 18

    # 更新 versions.json（拉取最新 sha256 等）
    ./versions.sh "$major" || {
        log ERROR "versions.sh failed for major $major"
        exit 1
    }

    # 生成所有变体（forky, alpine3.23, alpine3.22）的 Dockerfile 和 Makefile
    ./apply-templates.sh "$major" || {
        log ERROR "apply-templates.sh failed for major $major"
        exit 1
    }

    popd
}

make_image_with_retry()
{
    local build_dir="$1"
    for ((i=1; i<=10; i++)); do
        log INFO "第${i}次构建 $build_dir"
        if make image -C "$build_dir"; then
            return
        fi
        sleep 10
    done
}

docker_build()
{
    local version="$1"
    local major="${version%%.*}"
    log INFO "Building Docker images for major $major ..."

    local dockerfiles=$(find "./template/$major" -name 'Dockerfile')
    for dockerfile in $dockerfiles; do
        local build_dir=$(dirname "$dockerfile")
        make_image_with_retry "$build_dir"
    done

    log INFO "All variants for major $major built successfully"
}

docker_push()
{
    local version="$1"
    local major="${version%%.*}"
    log INFO "Pushing Docker images for major $major ..."

    local dockerfiles=$(find "./template/$major" -name 'Dockerfile')
    for dockerfile in $dockerfiles; do
        local build_dir=$(dirname "$dockerfile")
        make push -C "$build_dir"
    done

    log INFO "All variants for major $major pushed"
}

process()
{
    version="$1"
    prepare "$version"
    docker_build "$version"
    docker_push "$version"
}

process "$1"
