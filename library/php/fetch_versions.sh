#!/bin/bash
set -eo pipefail

fetch_versions(){

    #local versions=$(gh api repos/python/cpython/tags --paginate --jq '.[].name' | \
	#	grep -vE '[abcr]+' |
    #  	grep -E '^v3' | \
    #  	grep -Eo 'v3\.[0-9]+' | \
    #  	grep -Eo '3\.[0-9]+' | \
    #  	sort -uV)
	local versions=$(wget -qO- https://github.com/ruby/www.ruby-lang.org/raw/master/_data/releases.yml | \
		yq -r '@json' | \
		jq -r 'map(.version) | .[]' | \
		grep -vE '[a-z]' | sort -V)

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
