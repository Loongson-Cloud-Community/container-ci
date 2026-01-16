#!/bin/bash
#
# 由于 nginx 脚本不支持指定版本进行构建，仅支持最新版本构建，只能返回一个版本
#
set -eo pipefail

DEBIAN_MIRROR='https://snapshot.debian.org/archive/debian-ports'
declare -a IGNORE_VERSIONS=()

# Usage: get_github_latest $org $proj
# Return: (latest_tag)
get_github_latest()
{
    local org=$1
    local proj=$2
    curl -s https://api.github.com/repos/$org/$proj/tags | jq -r '.[].name'
}

fetch_versions() {
    local versions=$(get_github_latest "nginx" "pkg-oss" \
            | grep -E '^[0-9]+\.[0-9]+\.[0-9]+-[0-9]$' \
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
