#!/bin/bash

main(){
    local version=$1
    local v1=$(echo "$version" | cut -d. -f1)
    local url="https://www.php.net/releases/index.php?json&version=${v1}&max=500"
    local sha256=$(curl "$url" | jq -r --arg version $version '.[$version].source.[2].sha256')
    echo "$sha256"
}

main "$1"
