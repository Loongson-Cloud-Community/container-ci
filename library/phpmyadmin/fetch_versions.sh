#!/bin/bash
set -eo pipefail

PROCESSED_FILE="processed_versions.txt"
IGNORE_FILE="ignore_versions.txt"

fetch_versions() {
    # 获取最新的 phpMyAdmin 稳定版本
    local latest=$(curl -fsSL 'https://www.phpmyadmin.net/home_page/version.json' | jq -r '.version' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$')
    if [[ -z "$latest" ]]; then
        echo "ERROR: Failed to fetch latest version" >&2
        exit 1
    fi
    echo "$latest"
}

version=$(fetch_versions)
if grep -Fxq "$version" "$PROCESSED_FILE" 2>/dev/null; then
    exit 0
fi
if grep -Fxq "$version" "$IGNORE_FILE" 2>/dev/null; then
    exit 0
fi
echo "$version"
