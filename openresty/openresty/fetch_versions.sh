#!/bin/bash

set -eo pipefail
set -u

readonly ORG='openresty'
readonly PROJ='openresty'
readonly STRIP_VERSION_PREFIX='true'

declare -a IGNORE_VERSIONS=()

# vx.y.z
readonly VERSION_REGEX='^v[0-9]+.[0-9]+.[0-9]+$'

# Usage: get_github_tags $org $proj
# Return: (tags)
get_github_tags()
{
    local org=$1
    local proj=$2

    curl -s https://api.github.com/repos/"$org"/"$proj"/releases/latest \
            | jq -r ".tag_name"
}

fetch_versions() {
    local versions
    versions=$(get_github_tags "$ORG" "$PROJ")

    # strip v
    if [[ "$STRIP_VERSION_PREFIX" == 'true' ]]; then
        versions=$(echo "$versions" \
            | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
            || true)
    fi
    # 过滤 忽略和已构建的版本
    echo "$versions" \
        | grep -Fvx -f <(printf "%s\n" "${IGNORE_VERSIONS[@]}") \
        | grep -Fvx -f processed_versions.txt \
        || true
}

fetch_versions
