#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# 获取 Tomcat 最新版本，并定义支持的变体列表
# 输出到当前目录（即 template/）的 versions.json
# ============================================================

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
    versions=( */ )
    json='{}'
else
    json="$(< versions.json 2>/dev/null || echo '{}')"
fi
versions=( "${versions[@]%/}" )

# 仅使用 temurin 基础镜像的 Debian 变体（JDK 和 JRE）
# 官方 Tomcat 无 Alpine 版本，故不包含 Alpine
allVariants='[
  "jdk8/temurin",
  "jdk11/temurin",
  "jdk17/temurin",
  "jdk21/temurin",
  "jdk25/temurin",
  "jre8/temurin",
  "jre11/temurin",
  "jre17/temurin",
  "jre21/temurin",
  "jre25/temurin"
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
            possibleVersionStable="${possibleVersion%%-M*}"
            if grep -qP "^\Q$possibleVersionStable\E\$" <<<"$possibleVersions"; then
                echo >&2 "note: skipping '$possibleVersion' as we have '$possibleVersionStable'"
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
                ))
            ),
        }
    ')"
done

jq <<<"$json" -S . > versions.json
