#!/usr/bin/env bash
set -Eeuo pipefail

sha256sum() {
	local version=$1
	curl -fsSL "https://ftp.postgresql.org/pub/source/v${version}/postgresql-${version}.tar.bz2.sha256" | cut -d' ' -f1
}

version_json() {
	local version=$1
	local sha256=$(sha256sum $version)
	local major=$(echo $version | cut -d. -f1)
	local llvmver='19'
	jq -cnr \
		--arg version $version \
		--arg sha256 $sha256 \
		--arg major $major \
		--arg llvmver $llvmver \
		'{
            version: ($version),
            sha256: ($sha256),
            major: ($major),
            llvmver: ($llvmver),
        }'
}

main() {
    local version=$1
    local sha256=$(sha256sum $version)
    local version_json=$(version_json $version $sha256)
    jq -n \
        --arg version $version \
        --argjson version_json $version_json \
        '{
            ($version): ($version_json)
        }' >alpine-versions.json

}

set -x
main "$1"
