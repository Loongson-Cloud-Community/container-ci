#!/bin/bash

set -eo pipefail
set -x

readonly ORG='apache'
readonly PROJ='httpd'

declare -a IGNORE_VERSIONS=()

declare -r VersionExpr='^[0-9]+.[0-9]+.[0-9]+$'

# Usage: get_github_tags $org $proj
# Return: (tags)
get_github_tags()
{
    local org=$1
    local proj=$2
    git ls-remote --tags https://github.com/$org/$proj.git \
    | cut -d'/' -f3- \
    | cut -d'^' -f1 \
    | grep -E "$VersionExpr" \
    | sort -rV \
    | uniq


}

fetch_versions() {
    local versions=$(get_github_tags "$ORG" "$PROJ" \
            | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
            | sort -rV \
            | head -2
    )
    ## 过滤 忽略和已构建的版本
    (echo "$versions" \
        | grep -Fvx -f <(printf "%s\n" ${IGNORE_VERSIONS[@]}) \
        | grep -Fvx -f versions.txt
    ) || true

}

fetch_versions
