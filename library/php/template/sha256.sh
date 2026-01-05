#!/bin/bash
set -e;

main(){
    local version=$1
    local v1=$(echo "$version" | cut -d. -f1)
    local url="https://www.php.net/releases/index.php?json&version=${v1}&max=500"
    local res_info=`curl "$url"`
    local sha256=`echo "${res_info}" | jq -r --arg version $version '.[$version].source[2].sha256'`
    echo "$sha256"
}

main "$1"
