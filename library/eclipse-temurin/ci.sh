#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="processed_versions.txt"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"

main() {
    # 1. 更新版本信息
    log "Fetching latest Temurin versions..."
    ./fetch_versions.sh

    # 2. 读取所有主版本号
    VERSIONS=$(jq -r 'keys[]' "$VERSIONS_JSON")
    if [ -z "$VERSIONS" ]; then
        log "No versions found"
        exit 1
    fi

    # 3. 对每个版本调用 process_version.sh
    for ver in $VERSIONS; do
        FULL_VERSION=$(jq -r ".\"$ver\".version" "$VERSIONS_JSON")
        if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
            continue
        fi
        # 检查 processed_versions.txt 中是否已记录该完整版本号
        if grep -Fxq "$FULL_VERSION" "$PROCESSED_FILE" 2>/dev/null; then
            log "Version $ver ($FULL_VERSION) already built, skipping"
            continue
        fi
        log "Processing version $ver ($FULL_VERSION)"
        ./process_version.sh "$ver"
        echo "$FULL_VERSION" >> "$PROCESSED_FILE"
    done

    # 4. Git 提交（如果有更新）
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git add template/ "$PROCESSED_FILE" 2>/dev/null || true
        if ! git diff --cached --quiet; then
            git config user.name "CI Bot" || true
            git config user.email "ci@loongson.cn" || true
            git commit -m "Update Eclipse Temurin images" || true
            git pull --rebase || true
            git push origin main || true
        fi
    fi

    log "CI finished."
}

main
