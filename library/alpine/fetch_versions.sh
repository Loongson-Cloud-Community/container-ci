#!/bin/bash
set -eo pipefail

readonly FTP_BASE='https://cz.alpinelinux.org/alpine'

fetch_versions(){

    local versions=$(wget ${FTP_BASE} -qO- \
		| grep -o '>v.*<' \
		| grep -v '\-rc' \
		| sed -r 's:>v(.*)\/<:\1:' )

    echo "$versions" \
        | sort -V \
        | grep -Fxv -f processed_versions.txt \
        | { grep -Fxv -f ignore_versions.txt || [ $? -eq 1 ]; }

}


fetch_versions
