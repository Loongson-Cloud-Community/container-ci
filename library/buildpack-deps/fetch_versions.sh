#!/bin/bash
set -eo pipefail

#readonly BASE_URL='https://go.dev/dl/?mode=json'
#readonly IGNORE_VERSIONS=()
#
fetch_versions() {
    local versions=("debian")

    echo $versions | grep -Fxv -f processed_versions.txt || true
}

fetch_versions
