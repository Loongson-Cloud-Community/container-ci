#!/bin/bash
set -eo pipefail

fetch_versions(){

    local versions=$(wget -qO- 'https://ftp.postgresql.org/pub/source/' \
        | grep -oE '>v.*<' \
        | sed -r 's:>v(.*)/<:\1:g' \
        | grep -v 'beta' \
        | sort -V)

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
