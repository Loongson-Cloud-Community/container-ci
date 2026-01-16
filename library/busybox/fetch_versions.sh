#!/bin/bash

set -eo pipefail
set -u

readonly ORG='mirror'
readonly PROJ='busybox'

declare -a IGNORE_VERSIONS=()

VersionExpr='^[0-9]+.[0-9]+.[0-9]+$'
# Usage: get_github_tags $org $proj
# Return: (tags)
get_github_tags()
{
    org="$1"
    proj="$2"
    git ls-remote --tags https://github.com/$org/$proj.git \
    | cut -d'/' -f3- \
    | cut -d'^' -f1 \
    | sed 's/_/./g' \
    | grep -E "$VersionExpr"
}

fetch_versions() {
    local versions=$(get_github_tags "$ORG" "$PROJ" \
            | sort -rV \
            | head -2
    )
    ## 过滤 忽略和已构建的版本
    (echo "$versions" \
        | grep -Fvx -f <(printf "%s\n" ${IGNORE_VERSIONS[@]}) \
        | grep -Fvx -f processed_versions.txt
    ) || true

}

fetch_versions
