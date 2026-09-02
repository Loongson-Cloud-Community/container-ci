#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$(dirname $0)/lib.sh"

VERSIONS_JSON="./template/versions.json"

fetch_versions() {
    if [ ! -f "$VERSIONS_JSON" ]; then
        log ERROR "$VERSIONS_JSON not found. Run ci.sh first to fetch upstream."
        exit 1
    fi

    # 获取所有大版本（如 10.6, 11.3, 11.4），过滤掉 -rc 版本
    local major_versions=$(jq -r 'keys[] | select(contains("-rc") | not)' "$VERSIONS_JSON" | sort -V)

    for major in $major_versions; do
        # 获取完整版本号（如 10.6.8）
        local full_version=$(jq -r ".\"$major\".version" "$VERSIONS_JSON")
        
        if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
            continue
        fi

        # 检查完整版本是否已处理
        if grep -Fxq "$full_version" processed_versions.txt 2>/dev/null; then
            continue
        fi

        echo "$full_version"
    done
}

fetch_versions
