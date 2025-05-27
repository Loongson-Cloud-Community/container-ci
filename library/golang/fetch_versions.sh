#!/bin/bash
set -eo pipefail

readonly BASE_URL='https://go.dev/dl/?mode=json'
readonly IGNORE_VERSIONS=()

fetch_versions() {
    local versions=$(wget -qO- "$BASE_URL" \
        | jq -r '.[].version' \
        |  grep -oP 'go\K\d+\.\d+')

    (echo "$versions" \
        | sort -V \
        | grep -Fxv -f versions.txt \
        | grep -Fxv -f <(printf "%s\n" "${IGNORE_VERSIONS[@]}")) || true
}

fetch_versions
