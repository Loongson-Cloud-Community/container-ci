#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

PROCESSED_FILE="processed_versions.txt"
IGNORE_FILE="ignore_versions.txt"

main() {
    # 1. 调用官方 update.sh 生成 versions.json 和所有 Dockerfile
    log "Generating versions and Dockerfiles with official update.sh..."
    cd template
    ./update.sh
    cd ..

    # 2. 需要处理的系列（latest 和 cli，beta 可忽略）
    series_list=("latest" "cli")

    for series in "${series_list[@]}"; do
        current_version=$(jq -r ".[\"$series\"].version" template/versions.json)
        if [ -z "$current_version" ] || [ "$current_version" = "null" ]; then
            log "ERROR: Cannot get version for $series"
            continue
        fi

        # 检查是否忽略
        if grep -Fxq "$series" "$IGNORE_FILE" 2>/dev/null; then
            log "Series $series is in ignore list, skipping"
            continue
        fi

        # 检查是否已处理且版本未变
        if grep -q "^$series:$current_version$" "$PROCESSED_FILE" 2>/dev/null; then
            log "Series $series already up-to-date ($current_version), skipping"
            continue
        fi

        log "Processing series $series ($current_version)"
        ./process_version.sh "$series"
        # 更新记录文件
        sed -i "/^$series:/d" "$PROCESSED_FILE" 2>/dev/null || true
        echo "$series:$current_version" >> "$PROCESSED_FILE"
    done

    # 可选：Git 提交
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$PROCESSED_FILE" template/versions.json template/ 2>/dev/null || true
        if ! git diff --cached --quiet; then
            git config user.name "Huang Yang" || true
            git config user.email "huangyang@loongson.cn" || true
            git commit -m "Update WordPress images" || true
            git pull --rebase || true
            git push origin main || true
        fi
    fi

    log "CI finished."
}

main
