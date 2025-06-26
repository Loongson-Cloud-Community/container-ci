#!/bin/bash
set -eo pipefail

fetch_versions(){

    local versions=$(gh api repos/python/cpython/tags --paginate --jq '.[].name' | \
		grep -vE '[abcr]+' |
      	grep -E '^v3' | \
      	grep -Eo 'v3\.[0-9]+' | \
      	grep -Eo '3\.[0-9]+' | \
      	sort -uV)

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
