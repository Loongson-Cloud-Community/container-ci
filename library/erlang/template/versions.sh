#!/bin/bash

set -eo pipefail

fetch_latest_patch_version(){
	local version=$1
	local latest_patch_version=$(gh release list --repo erlang/otp --exclude-drafts --exclude-pre-releases --limit 100 | \
		awk '{print $2}' | \
		grep -E "$version"'\.' | \
		head -n 1)
	echo "$latest_patch_version"
}

fetch_otp_sha256(){
	local version=$1
	local sha256_=$(wget -qO- https://github.com/erlang/otp/releases/download/OTP-${version}/SHA256.txt | \
		grep 'otp_src' | \
		awk '{print $1}')
	echo $sha256_
}

fetch_rebar3_latest_version(){
	local latest_version=$(gh release list --repo erlang/rebar3 --exclude-drafts --exclude-pre-releases --limit 100 | \
		awk '{print $1}' | \
		head -n 1)
	echo "${latest_version}"
}

fetch_rebar3_sha256(){
	local rebar3_version=$1
	local sha256_=$(wget -qO- https://github.com/erlang/rebar3/archive/${rebar3_version}.tar.gz | \
		sha256sum | \
		awk '{print $1}')
	echo "$sha256_"
}

main(){
	local otp_version=$1
	local otp_latest_patch_version=$(fetch_latest_patch_version $otp_version)
	local otp_sha256=$(fetch_otp_sha256 $otp_latest_patch_version)
	local rebar3_version=$(fetch_rebar3_latest_version)
	local rebar3_sha256=$(fetch_rebar3_sha256 $rebar3_version)
	jq \
		--arg otp_version "$otp_latest_patch_version"  \
		--arg otp_download_sha256 "$otp_sha256"  \
		--arg rebar3_version "$rebar3_version"  \
		--arg rebar3_download_sha256 "$rebar3_sha256"  \
		'.otp_version=$otp_version |
		.otp_download_sha256=$otp_download_sha256 |
		.rebar3_version=$rebar3_version |
		.rebar3_download_sha256=$rebar3_download_sha256
		' versions-template.json >versions.json
}

main "$1"
