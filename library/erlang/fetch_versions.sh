#!/bin/bash
set -eo pipefail

fetch_versions(){

	local versions=$(gh api repos/erlang/otp/tags --paginate --jq '.[].name' | \
		grep 'OTP-' | \
		awk -F '-' '{print $2}' | \
		grep -oE '^[0-9]+' | \
		sort -uV)

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
