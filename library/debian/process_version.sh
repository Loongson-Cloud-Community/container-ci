#!/bin/bash

# usage: process_version.sh 20250521T073957Z

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='debian'
readonly SUITE='sid'
readonly ARCH='loong64'
readonly OUT_DIR='out'

readonly -A DEBIAN_VERSIONS=(
    ["13"]="trixie"
    ["12"]="bookworm"
    ["11"]="bullseye"
    ["10"]="buster"
)

debian_version=$(cat $(dirname $0)/debian.version)
debian_version_name=${DEBIAN_VERSIONS[$debian_version]}

# 20250521
time_version="${1%T*}"

# (13 trixie sid sid-20250521 latest)
debian_tags=(
    "$debian_version"
    "$debian_version_name"
    "sid"
    "sid-$time_version"
    "latest"
)

# (13-slim trixie-slim sid-slim sid-20250521-slim)
debian_slim_tags=(
    "$debian_version-slim"
    "$debian_version_name-slim"
    "sid-slim"
    "sid-$time_version-slim"
)

# Prepare $version
prepare()
{
    local version="$1"
    log INFO "Preparing version $version"

    # validate version
    [[ "$1" =~ ^[0-9]{8}T[0-9]{6}Z$  ]] || {
        log ERROR "Invalid version format: $1. Expected format: 20250501T015255Z"
        exit 1
    }

    mkdir -p "$OUT_DIR"

}

# convert "20250501T015255" to "2025-05-01T01:52:55Z"
format_time()
{
    echo "$1" | sed -E 's/([0-9]{4})([0-9]{2})([0-9]{2})T([0-9]{2})([0-9]{2})([0-9]{2})/\1-\2-\3T\4:\5:\6/'
}

# Build rootfs build_rootfs 20250501T015255Z
build_rootfs()
{
    formatted=$(format_time "$1")
    timestamp=$(date -d "$formatted" +%s)
    docker run --privileged -v "$(pwd)"/"$OUT_DIR":/v -w /v \
        -e https_proxy="$https_proxy" \
        -e http_proxy="$http_proxy" \
        debuerreotype/debuerreotype:latest \
        /opt/debuerreotype/examples/debian.sh --ports --arch "$ARCH" . "$SUITE" "@$timestamp"

    # 修改 rootfs url 为固定的 snapshot url
    snapshotUrl=$(cat ./"$OUT_DIR"/"$time_version"/"$ARCH"/snapshot-url)
    ./modify-rootfs-url.sh "$OUT_DIR/$time_version/$ARCH/$SUITE/rootfs.tar.xz" "$snapshotUrl"
    ./modify-rootfs-url.sh "$OUT_DIR/$time_version/$ARCH/$SUITE/slim/rootfs.tar.xz" "$snapshotUrl"
}

build_images()
{
    # build debian
    targets=""
    for tag in "${debian_tags[@]}";
    do
        targets+=" -t $REGISTRY/$ORG/$PROJ:$tag"
    done
    docker build -f Dockerfile \
        $targets \
        ./"$OUT_DIR"/"$time_version"/"$ARCH"/"$SUITE"

    # build debian slim
    targets=""
    for tag in "${debian_slim_tags[@]}";
    do
        targets+=" -t $REGISTRY/$ORG/$PROJ:$tag"
    done
    docker build -f Dockerfile \
        $targets \
        "$OUT_DIR"/"$time_version"/"$ARCH"/"$SUITE/slim"
}

upload_rootfs()
{
    # upload
    local debian_tar="$OUT_DIR"/"$time_version"/"$ARCH"/"$SUITE"/rootfs.tar.xz
    local debian_slim_tar="$OUT_DIR"/"$time_version"/"$ARCH"/"$SUITE"/slim/rootfs.tar.xz
    upload_release 'debian' 'rootfs' "$1" "$debian_tar"
    upload_release 'debian' 'rootfs-slim' "$1" "$debian_slim_tar"
}

upload_images()
{
    # upload debian and debian-slim
    for tag in "${debian_tags[@]}" "${debian_slim_tags[@]}";
    do
        docker push "$REGISTRY/$ORG/$PROJ:$tag"
    done
}

main()
{
    local version="$1"
    prepare "$version"
    build_rootfs "$version"
    build_images "$version"
    upload_rootfs "$version"
    upload_images "$version"
}

main "$1"
