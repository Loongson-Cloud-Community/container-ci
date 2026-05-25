#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
        versions=( */ )
        json='{}'
else
        json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

# LoongArch 可用的变体列表（基于 debian-forky 的 JDK）
allVariants='[
  "jdk8/debian-forky",
  "jdk11/debian-forky",
  "jdk17/debian-forky",
  "jdk21/debian-forky",
  "jdk25/debian-forky"
]'
export allVariants

for version in "${versions[@]}"; do
        majorVersion="${version%%.*}"

        possibleVersions="$(
                curl -fsSL --compressed "https://downloads.apache.org/tomcat/tomcat-$majorVersion/" \
                        | grep '<a href="v'"$version." \
                        | sed -r 's!.*<a href="v([^"/]+)/?".*!\1!' \
                        | sort -rV
        )"
        fullVersion=
        sha512=
        for possibleVersion in $possibleVersions; do
                if [[ "$possibleVersion" == *-M* ]]; then
                        # "sort -V" considers "10.1.0-M17" to be newer than "10.1.0" even though it's a pre-release 😅
                        possibleVersionStable="${possibleVersion%%-M*}"
                        if grep -qP "^\Q$possibleVersionStable\E\$" <<<"$possibleVersions"; then
                                echo >&2 "note: skipping '$possibleVersion' as we seem to have '$possibleVersionStable'"
                                continue
                        fi
                fi
                if possibleSha512="$(
                        curl -fsSL "https://downloads.apache.org/tomcat/tomcat-$majorVersion/v$possibleVersion/bin/apache-tomcat-$possibleVersion.tar.gz.sha512" \
                                | cut -d' ' -f1
                )" && [ -n "$possibleSha512" ]; then
                        fullVersion="$possibleVersion"
                        sha512="$possibleSha512"
                        break
                fi
        done
        if [ -z "$fullVersion" ]; then
                echo >&2 "error: failed to find latest release for $version"
                exit 1
        fi

        echo "$version: $fullVersion ($sha512)"

        export version fullVersion sha512
        json="$(jq <<<"$json" -c '
                include "shared";
                .[env.version] = {
                        version: env.fullVersion,
                        sha512: env.sha512,
                        variants: (
                                env.allVariants | fromjson
                                | map(select(
                                        (
                                                split("/")[0]
                                                | ltrimstr("jdk") | ltrimstr("jre")
                                                | tonumber
                                        ) as $java_version
                                        | is_supported_java_version($java_version)
                                                and (
                                                        (is_native_ge_2 | not)
                                                        or has_openssl_ge_3(.)
                                                )
                                ))
                        ),
                }
        ')"
done

jq <<<"$json" -S . > versions.json
