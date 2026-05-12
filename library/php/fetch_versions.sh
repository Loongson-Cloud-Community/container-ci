#!/bin/bash
set -eo pipefail

VERSIONS_JSON="./template/versions.json"

fetch_versions() {
    if [ ! -f "$VERSIONS_JSON" ]; then
        echo "ERROR: $VERSIONS_JSON not found. Please run 'cd template && ./update.sh' first." >&2
        exit 1
    fi

    # 获取所有主版本（keys），过滤掉包含 "-rc" 的
    local versions=$(jq -r 'keys[] | select(contains("-rc") | not)' "$VERSIONS_JSON" | sort -V)

    # 增量模式：过滤 ignore_versions.txt 和 processed_versions.txt
    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }
}

fetch_versions
