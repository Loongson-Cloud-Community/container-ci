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

    sha256="$(wget -qO- "https://downloads.apache.org/httpd/httpd-$version.tar.bz2.sha256" | cut -d' ' -f1)"
    export sha256


    patchesUrl="https://downloads.apache.org/httpd/patches/apply_to_$version"
    patches=()
    if wget --quiet --spider -O /dev/null -o /dev/null "$patchesUrl/"; then
    	patchFiles="$(
    		wget -qO- "$patchesUrl/?C=M;O=A" \
    			| grep -oE 'href="[^"]+[.]patch"' \
    			| cut -d'"' -f2 \
    			|| true
    	)"
    	for patchFile in $patchFiles; do
    		patchSha256="$(wget -qO- "$patchesUrl/$patchFile" | sha256sum | cut -d' ' -f1)"
    		[ -n "$patchSha256" ]
    		patches+=( "$patchFile" "$patchSha256" )
    	done
    fi
    if [ "${#patches[@]}" -gt 0 ]; then
    	echo " - ${patches[*]}"
    fi

    patchesRaw=${patches[*]}
    export patchesRaw

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
                            sha256: env.sha256,
                            patches: env.patchesRaw
                    }
                '
        )"
done

jq <<<"$json" -S . > versions.json
