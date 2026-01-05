#!/bin/bash
set -eo pipefail

latest_version() {
	local -r version="$1"
	local url="https://cz.alpinelinux.org/alpine/v${version}/releases/loongarch64"
	wget -qO- "${url}" | \
		grep '^<a href'  | \
		grep 'minirootfs' | \
		grep -v '_rc' | \
		grep 'loongarch64.tar.gz<' | \
		grep -o ">alpine-minirootfs-${version}.*-loongarch64.tar.gz<" | \
		sed -r 's/>alpine-minirootfs-(.*)-loongarch64.tar.gz</\1/' | \
		sort -rV | \
		head -n 1
}

tags() {
	local latest_version="$1"
	local version_1=$(echo $latest_version | cut -d. -f1)
	local version_2=$(echo $latest_version | cut -d. -f1,2)
	local version_3=$(echo $latest_version | cut -d. -f1,2,3)
	echo "${version_1},${version_2},${version_3}"
}

url() {
	local version=$1
	latest_version=$(latest_version $version)
	echo "https://cz.alpinelinux.org/alpine/v${version}/releases/loongarch64/alpine-minirootfs-${latest_version}-loongarch64.tar.gz"
}

versions_json() {
	version=$1
	latest_version=$(latest_version $version)
	tags_=$(tags $latest_version)
	url_=$(url $version)
	jq -n \
		--arg version $version \
		--arg tags_ $tags_ \
		--arg url_ $url_ '{
			($version): {
				url: $url_,
				tags: $tags_,
			},
		}' \
	>versions.json
}

versions_json "$1"
