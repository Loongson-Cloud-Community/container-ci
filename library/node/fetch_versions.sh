#!/bin/bash
set -eo pipefail

fetch_versions() {

	local versions=$(gh api repos/nodejs/node/tags --paginate --jq '.[].name' |
		grep -v 'r' |
		grep -v 'R' |
		grep -v 'f' |
		grep -v 'head' |
		sed -r 's/v//g' |
		sort -V)
	echo "$versions" |
		grep -Fxv -f ignore_versions.txt |
		{ grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
