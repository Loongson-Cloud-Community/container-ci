#!/bin/bash

set -e

yarn_latest_version() {
	gh api repos/yarnpkg/yarn/tags --paginate --jq '.[].name' |
		grep -v 'R' |
		grep -v 'r' |
		grep -v 'e' |
		grep -v '\-' |
		grep 'v' |
		sed -r 's/^v//' |
		sort -V |
		tail -n 1
}

generate_single_version_info() {
	local node_version="$1"
	local yarn_version=$(yarn_latest_version)
	jq -ncr \
		--arg yarn_version $yarn_version \
		--arg node_version $node_version \
		'{ 
            ($node_version): {
                yarn_version: $yarn_version
            } 
         }'
}

append_single_version_info() {

	local node_version="$1"
	local node_version_info=$(generate_single_version_info ${node_version})
	# 获取原始数据
	local origin_data=$(jq <versions.json -cr \
		--arg node_version $node_version \
		'del(.[$node_version])')
	# 数据追加
	jq -n \
		--argjson node_version_info $node_version_info \
		--argjson origin_data $origin_data \
		'($node_version_info) + ($origin_data)' >versions.json
}

append_single_version_info "$1"
