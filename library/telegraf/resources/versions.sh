#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
        versions=( "${!otpMajors[@]}" )
        # try RC releases after doing the non-RCs so we can check whether they're newer (and thus whether we should care)
        versions+=( "${versions[@]/%/-rc}" )
        json='{}'
else    
        json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

alpine='3.22'
debian="trixie"
export debian alpine

for version in "${versions[@]}"; do
    export version

    json="$(
            jq <<<"$json" -c '
                    .[env.version] = {
                            debian: {
                                version: env.debian
                            },
                            alpine: {
                                version: env.alpine
                            },
                            version: env.version,
                    }
                '
        )"
done

jq <<<"$json" -S . > versions.json
