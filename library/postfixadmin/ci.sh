#!/bin/bash
set -eo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

PROCESSED_FILE="processed_versions.txt"
VERSIONS_JSON="template/versions.json"

main() {
    # 1. 获取最新版本
    log "Fetching latest version..."
    ./fetch_versions.sh

    # 2. 生成 Dockerfile
    log "Generating Dockerfiles..."
    ./apply-templates.sh

    # 3. 读取版本
    if [ ! -f "$VERSIONS_JSON" ]; then
        log ERROR "versions.json not found"
        exit 1
    fi
    version=$(jq -r 'keys[0]' "$VERSIONS_JSON")
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        log ERROR "Failed to parse version"
        exit 1
    fi

    # 4. 检查是否已构建
    if [ -f "$PROCESSED_FILE" ] && grep -Fxq "$version" "$PROCESSED_FILE"; then
        log INFO "Version $version already built, skipping"
        exit 0
    fi

    # 5. 构建并推送
    log "Building and pushing version $version"
    ./process_version.sh

    # 6. 记录已构建版本
    echo "$version" >> "$PROCESSED_FILE"
    log INFO "Recorded $version in $PROCESSED_FILE"

    # 7. Git 提交（可选）
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$PROCESSED_FILE" "$VERSIONS_JSON" template/ 2>/dev/null || true
        if ! git diff --cached --quiet; then
            git config user.name "CI Bot" || true
            git config user.email "ci@loongson.cn" || true
            git commit -m "Update postfixadmin to $version" || true
            git pull --rebase || true
            git push origin main || true
        fi
    fi
}

main
