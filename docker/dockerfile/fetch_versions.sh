#!/bin/bash

set -eo pipefail
set -u

readonly ORG='moby'
readonly PROJ='buildkit'

declare -a IGNORE_VERSIONS=()

# Usage: get_github_tags $org $proj
# Return: (tags)
get_github_tags()
{
    local org=$1
    local proj=$2
    curl -s https://api.github.com/repos/$org/$proj/tags | jq -r '.[].name'
}

fetch_versions() {
 local versions=$(bash scripts/get-tags.sh | jq -r '.[]')  # 直接读取 JSON

    ## 过滤 忽略和已构建的版本
    echo "$versions" \
        | grep -Fvx -f <(printf "%s\n" "${IGNORE_VERSIONS[@]}") \
        | grep -Fvx -f processed_versions.txt \
        || true
}

fetch_versions
