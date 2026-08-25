#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
VERSIONS_JSON="${SCRIPT_DIR}/versions.json"
IGNORE_FILE="${SCRIPT_DIR}/ignore_versions.txt"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

fetch_versions() {
    # 获取所有 Git tag，过滤出 v0.x.x 格式
    local tags=$(git ls-remote --tags https://github.com/wallarm/api-firewall.git \
        | grep -oE 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' \
        | sed 's|refs/tags/||' \
        | sort -Vr)

    if [ -z "$tags" ]; then
        log "ERROR: Failed to fetch tags"
        return 1
    fi

    # 读取忽略列表（完整版本号）
    local ignore_list=""
    if [ -f "$IGNORE_FILE" ]; then
        # 读取所有非注释行，用 | 连接，作为 grep 的 pattern
        ignore_list=$(cat "$IGNORE_FILE" | grep -v '^#' | tr '\n' '|' | sed 's/|$//')
        log "Ignore list: $ignore_list"
    fi

    # 提取大版本（0.9, 0.8, 0.7, 0.6），过滤忽略的版本
    declare -A latest_per_minor
    for tag in $tags; do
        # 检查是否在忽略列表中（精确匹配完整 tag）
        if [ -n "$ignore_list" ] && echo "$tag" | grep -qE "$ignore_list"; then
            log "Skipping ignored version: $tag"
            continue
        fi
        # 提取大版本号（如 0.6）
        local major_minor=$(echo "$tag" | grep -oE '[0-9]+\.[0-9]+')
        if [ -z "${latest_per_minor[$major_minor]}" ]; then
            latest_per_minor[$major_minor]="$tag"
        fi
    done

    # 生成 versions.json
    echo "{" > "$VERSIONS_JSON"
    local first=true
    for minor in $(echo "${!latest_per_minor[@]}" | tr ' ' '\n' | sort -Vr); do
        local tag="${latest_per_minor[$minor]}"
        local version="${tag#v}"
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$VERSIONS_JSON"
        fi
        echo "  \"$minor\": \"$version\"" >> "$VERSIONS_JSON"
        log "Found $minor -> $version"
    done
    echo "}" >> "$VERSIONS_JSON"

    log "Generated $VERSIONS_JSON"
}

fetch_versions
