#!/bin/bash
set -e

PROCESSED_FILE="processed_versions.txt"
IGNORE_FILE="ignore_versions.txt"

fetch_versions() {
    local latest=$(curl -fsSL -H "User-Agent: Mozilla/5.0" \
        "https://api.github.com/repos/phpmyadmin/phpmyadmin/releases/latest" | jq -r '.tag_name')
    latest=${latest#RELEASE_}          # 去除前缀 RELEASE_
    latest=${latest//_/.}              # 将所有下划线替换为点号
    echo "$latest"
}

version=$(fetch_versions)
if [ -z "$version" ]; then
    echo "ERROR: Failed to fetch latest version" >&2
    exit 1
fi

if grep -Fxq "$version" "$PROCESSED_FILE" 2>/dev/null; then
    exit 0
fi
if grep -Fxq "$version" "$IGNORE_FILE" 2>/dev/null; then
    exit 0
fi
echo "$version"
