#!/bin/bash
set -eo pipefail

readonly FTP_BASE='https://ftp.gnu.org/gnu/bash'
readonly IGNORE_VERSIONS=(
    "4.3"
    "5.0"
)

fetch_versions() {
    local versions=$(curl -fsSL "$FTP_BASE/" \
        | sed -rne '/^(.*[/"[:space:]])?bash-([0-9].+)[.]tar[.]gz([/"[:space:]].*)?$/s//\2/p' \
        | grep -E '^[4-9]+\.[0-9]+$')

    (echo "$versions" \
        | sort -V \
        | grep -Fxv -f versions.txt \
        | grep -Fxv -f <(printf "%s\n" "${IGNORE_VERSIONS[@]}")) || true
}

fetch_versions
