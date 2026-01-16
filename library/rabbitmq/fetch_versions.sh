#!/bin/bash

set -eo pipefail
set -e

readonly ORG='rabbitmq'
readonly PROJ='rabbitmq-server'

declare -a IGNORE_VERSIONS=()

# X.Y.Z
#declare -r VersionExpr='^[0-9]+.[0-9]+.[0-9]+$'

# vX.Y.Z
declare -r VersionExpr='^v[0-9]+.[0-9]+.[0-9]+$'

# Usage: get_github_tags $org $proj
# Return: (tags)
get_github_tags()
{
    local org=$1
    local proj=$2
    git ls-remote --tags https://github.com/$org/$proj.git \
        | cut -d'/' -f3- \
        | cut -d'^' -f1 \
        | grep -E "$VersionExpr"

    #curl -s https://api.github.com/repos/$org/$proj/tags | jq -r '.[].name'
}

fetch_versions() {
    local versions=$(get_github_tags "$ORG" "$PROJ" \
        | cut -c2- \
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
