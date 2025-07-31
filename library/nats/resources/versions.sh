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
export alpine

for version in "${versions[@]}"; do
    export version

    sha256file=$(wget -qO- http://cloud.loongnix.cn/releases/loongarch64/nats-io/nats-server/${version}/SHA256SUMS)
    echo $sha256file

    for arch in loong64; do
        archsha=$(echo $sha256file | grep "$arch.tar.gz" | cut -d ' ' -f1)
        export ${arch}sha256=$archsha
    done

    json="$(
            jq <<<"$json" -c '
                    .[env.version] = {
                            alpine: {
                                version: env.alpine
                            },
                            version: env.version,
                            sha256: {
                                loong64: env.loong64sha256,
                            },
                    }
                '
        )"
done

jq <<<"$json" -S . > versions.json
