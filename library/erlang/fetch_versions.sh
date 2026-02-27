#!/bin/bash
set -eo pipefail

fetch_versions(){

	local versions=$(gh api repos/erlang/otp/tags --paginate --jq '.[].name' \
                | grep -E '^OTP-' \
                | sed 's/OTP-//' \
                | sort -rV \
                | uniq \
                | head -3)

    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }

}

fetch_versions
