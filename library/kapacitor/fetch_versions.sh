#!/bin/bash

set -euo pipefail

readonly ORG='influxdata'
readonly PROJ='kapacitor'
readonly TAGS_COUNT='1'
readonly STRIP_VERSION_PREFIX='true'

declare -a IGNORE_VERSIONS=()

readonly VERSION_REGEX='^v[1-9]+.[0-9]+.[0-9]+$'

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
    | uniq
}

get_latest_tags_by_major()
{
    local org=$1
    local proj=$2
    local tags majors major

    tags=$(get_github_tags "$org" "$proj")

    majors=$(printf '%s\n' "$tags" \
        | sed -n 's/^v\([0-9]\+\)\..*/\1/p' \
        | sort -n \
        | uniq)

    for major in $majors; do
        printf '%s\n' "$tags" \
        | grep -E "^v${major}\.[0-9]+\.[0-9]+$" \
        | sort -V \
        | tail -"$TAGS_COUNT"
    done \
    | sort -V \
    | uniq
}

fetch_versions() {
    local versions
    versions=$(get_latest_tags_by_major "$ORG" "$PROJ")

    # strip prefix
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
