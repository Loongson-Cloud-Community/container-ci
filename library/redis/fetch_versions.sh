#!/bin/bash
set -eo pipefail

readonly FTP_BASE='https://raw.githubusercontent.com/redis/redis-hashes/master/README'

fetch_versions(){

    local versions=$(wget ${FTP_BASE} -qO- \
		| grep 'hash redis-' \
		| grep -v '\-rc' \
		| sed -r 's/hash redis-([0-9.]+).tar.gz.*$/\1/')

    echo "$versions" \
        | sort -V \
        | grep -Fxv -f processed_versions.txt \
        | grep -Fxv -f ignore_versions.txt

}




fetch_versions
