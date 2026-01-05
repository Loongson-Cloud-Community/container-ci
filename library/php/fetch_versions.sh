#!/bin/bash
set -eo pipefail

fetch_versions(){

	local versions=`gh api repos/php/php-src/tags --paginate --jq '.[].name' \
        | grep 'php-' \
        | grep -v 'RC' \
        | grep -v 'rc' \
        | grep -v 'b' \
        | grep -v 'dev' \
        | grep -v 'pre' \
        | grep -v 'pl' \
        | grep -v 'REL' \
        | grep -v 'alpha' \
        | awk -F '-' '{print $2}' \
        | sort -V`

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
