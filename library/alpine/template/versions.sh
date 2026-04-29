#!/bin/bash
set -eo pipefail

VERSION="$1"
MINOR_VERSION="${VERSION%.*}"
MAJOR_VERSION="${MINOR_VERSION%.*}"


versions_json() {
    tags="${MAJOR_VERSION},${MINOR_VERSION},${VERSION}"
    url="https://cz.alpinelinux.org/alpine/v${MINOR_VERSION}/releases/loongarch64/alpine-minirootfs-${VERSION}-loongarch64.tar.gz"
    jq -n \
    	--arg version ${MINOR_VERSION} \
    	--arg tags $tags \
    	--arg url $url '{
    		($version): {
    			url: $url,
    			tags: $tags,
    		},
    	}' \
    >versions.json
}

versions_json "$1"
