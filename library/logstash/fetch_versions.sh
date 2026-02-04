#!/bin/bash

set -eo pipefail
set -u

readonly ORG='elastic'
readonly PROJ='logstash'
readonly TAGS_COUNT='1'
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
    git ls-remote --tags https://github.com/${org}/${proj}.git \
    | cut -d'/' -f3- \
    | cut -d'^' -f1 \
    | grep -E "$VERSION_REGEX" \
    | sort -V \
    | uniq \
    | tail -"$TAGS_COUNT"
}

fetch_versions() {
    local versions
    versions=$(get_github_tags "$ORG" "$PROJ")

    # strip vx.y.z to x.y.z
    if [[ "$STRIP_VERSION_PREFIX" == 'true' ]]; then
        versions=$(echo "$versions" \
            | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' \
            || true)
    fi
    # 过滤 忽略和已构建的版本
    echo "$versions" \
        | grep -Fvx -f <(printf "%s\n" "${IGNORE_VERSIONS[@]}") \
        | grep -Fvx -f processed_versions.txt \
        || true
}

fetch_versions
