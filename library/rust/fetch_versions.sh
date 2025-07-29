#!/bin/bash
set -eo pipefail

fetch_versions(){

	local versions=$(gh api repos/rust-lang/rust/tags --paginate --jq '.[].name' | \
		grep -vE '[a-z]' | \
		sort -uV )

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
