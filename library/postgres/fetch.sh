#!/bin/bash
set -eo pipefail

fetch_versions(){

	local versions=$(gh api repos/postgres/postgres/tags --paginate --jq '.[].name' \
        | grep 'REL_' \
        | grep -v 'BETA' \
        | grep -v 'RC' \
        | sed -r 's:REL_(\d+)_(\d+):\1.\2:g' \
        | sort -V)

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
