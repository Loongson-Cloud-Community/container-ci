#!/bin/bash
set -eo pipefail

fetch_versions(){

    local org='prometheus-operator'
    local proj='prometheus-operator'
	local versions=`curl -s https://api.github.com/repos/prometheus-operator/prometheus-operator/releases/latest | jq -r ".tag_name" | sed -r 's:v::g'`

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
