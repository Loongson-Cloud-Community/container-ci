#!/bin/bash
set -eo pipefail

VERSIONS_JSON="./template/versions.json"

fetch_versions() {
    if [ ! -f "$VERSIONS_JSON" ]; then
        echo "ERROR: $VERSIONS_JSON not found. Please run 'cd template && ./update.sh' first." >&2
        exit 1
    fi

    # 获取所有主版本（keys），过滤掉包含 "-rc" 的
    local major_versions=$(jq -r 'keys[] | select(contains("-rc") | not)' "$VERSIONS_JSON" | sort -V)

    # 对于每个主版本，获取对应的完整版本号
    for major in $major_versions; do
        local full_version=$(jq -r ".\"$major\".version" "$VERSIONS_JSON")
        
        if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
            continue
        fi

        # 检查完整版本是否已处理
        if grep -Fxq "$full_version" processed_versions.txt 2>/dev/null; then
            continue
        fi

        # 检查是否在忽略列表中
        if grep -Fxq "$full_version" ignore_versions.txt 2>/dev/null; then
            continue
        fi

        echo "$full_version"
    done
}

fetch_versions
