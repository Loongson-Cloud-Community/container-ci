#!/bin/bash
set -eo pipefail

fetch_versions(){

    local org='prometheus'
    local proj='prometheus'
	local versions=`curl -s https://api.github.com/repos/${org}/${proj}/releases/latest | jq -r ".tag_name" | sed -r 's:v::g'`

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
