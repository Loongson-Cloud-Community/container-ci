#!/bin/bash
set -eo pipefail

fetch_versions(){

	local versions=`gh api repos/nextcloud/server/tags --paginate --jq '.[].name' | \
            grep -v '[a-uw-z]' | \
            grep -v '[A-UW-Z]' | \
            grep 'v' | \
            sed -r 's/v//g' | \
            sort -V`

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
