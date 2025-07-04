#!/usr/bin/env bash
set -Eeuo pipefail

version="$1"
variant="$2"

if [ ! -d $version/$variant ]; then
    echo "Build rootfs: invalid workspace $version/$variant"
fi
pushd $version/$variant

docker build \
    --progress=plain \
    --build-arg http_proxy=$(http_proxy) \
    --build-arg https_proxy=$(http_proxy) \
    -t  busybox-rootfs:$version-$variant \
    -f Dockerfile.builder \
    .

docker run --rm busybox-rootfs:$version-$variant \
        tar \
                --create \
                --gzip \
                --directory rootfs \
                --numeric-owner \
                --transform 's,^./,,' \
                --sort name \
                --mtime /usr/src/busybox.SOURCE_DATE_EPOCH --clamp-mtime \
                . \
                > "busybox.tar.gz"

popd
