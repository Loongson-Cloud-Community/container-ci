#!/bin/bash
set -eo pipefail

DEBIAN_MIRROR='https://snapshot.debian.org/archive/debian'

# 仅获取一个版本
fetch_versions() {
    
    year=$(date +%Y)
    month=$(date +%m)

    local version=$(wget -qO- "$DEBIAN_MIRROR?year=$year&month=$month"\
            | grep -oE 'href="[0-9]{8}T[0-9]{6}Z/"' \
            | tail -1 \
            | cut -d '"' -f 2 | cut -d '/' -f 1
        )

    echo "$version" | grep -Fxv -f processed_versions.txt || true
}

fetch_versions "$@"
