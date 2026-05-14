#!/bin/bash
set -eo pipefail

URL="https://www.loongnix.cn/zh/api/java/"
VERSIONS_JSON="template/versions.json"

MAJORS=(8 11 17 21 25)

mkdir -p template
echo '{}' > "$VERSIONS_JSON"

for major in "${MAJORS[@]}"; do
    echo "Processing JDK $major ..." >&2
    link=$(curl -sL "$URL" | grep -i "openjdk${major}" | grep -o 'https://[^"]*glibc2\.34\.tar\.gz' | head -1)
    if [ -z "$link" ]; then
        echo "  No glibc2.34 link found for JDK $major" >&2
        continue
    fi
    echo "  Found: $link" >&2

    basename=$(basename "$link")
    internal=$(echo "$basename" | grep -oP 'loongson\K[0-9.]+')

    if [[ "$major" == "8" ]]; then
        upstream=$(echo "$basename" | grep -oP 'jdk8u[0-9]+b[0-9]+' | sed 's/jdk//; s/b/-b/')
    else
        upstream=$(echo "$basename" | grep -oP 'jdk\K[0-9._]+' | sed 's/_/./g')
    fi

    # 获取 md5 校验和
    md5_url="${link}.md5sum"
    md5=$(curl -sL "$md5_url" | awk '{print $1}')
    if [ -z "$md5" ]; then
        echo "  Warning: MD5 not found for $basename" >&2
    fi

    if [ -z "$internal" ] || [ -z "$upstream" ]; then
        echo "  Failed to parse version from $basename" >&2
        continue
    fi
    echo "  internal=$internal, upstream=$upstream, md5=$md5" >&2

    jq --arg major "$major" \
       --arg upstream "$upstream" \
       --arg internal "$internal" \
       --arg url "$link" \
       --arg md5 "$md5" \
       '. + {($major): {
            version: $upstream,
            internal: $internal,
            url: $url,
            md5: $md5,
            arches: { loongarch64: { url: $url } },
            variants: []
        }}' "$VERSIONS_JSON" > "$VERSIONS_JSON.tmp"
    mv "$VERSIONS_JSON.tmp" "$VERSIONS_JSON"
done

# 基础镜像列表
BASES=("debian:forky" "debian:forky-slim" "openanolis:23.4")
for variant in "${BASES[@]}"; do
    for major in "${MAJORS[@]}"; do
        if jq -e ".\"$major\"" "$VERSIONS_JSON" > /dev/null; then
            jq --arg major "$major" --arg variant "$variant" \
                '.[$major].variants += [$variant] | .[$major].variants |= unique' \
                "$VERSIONS_JSON" > "$VERSIONS_JSON.tmp"
            mv "$VERSIONS_JSON.tmp" "$VERSIONS_JSON"
        fi
    done
done

echo "Generated $VERSIONS_JSON"
