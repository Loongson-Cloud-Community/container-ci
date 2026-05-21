#!/bin/bash
set -eo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

PROCESSED_FILE="processed_versions.txt"
IGNORE_FILE="ignore_versions.txt"

main() {
    # 进入 template 目录运行官方 update.sh
    if [ ! -d "template" ]; then
        log "ERROR: template directory not found"
        exit 1
    fi
    cd template
    if [ ! -x "./update.sh" ]; then
        log "ERROR: template/update.sh not found or not executable"
        exit 1
    fi
    log "Generating versions and Dockerfiles with official update.sh..."
    ./update.sh
    cd ..

    # 读取当前版本信息（从 template/versions.json）
    versions_json="template/versions.json"
    if [ ! -f "$versions_json" ]; then
        log "ERROR: $versions_json not found"
        exit 1
    fi

    # 获取所有主版本号
    versions=$(jq -r 'keys[]' "$versions_json")
    if [ -z "$versions" ]; then
        log "No versions found in $versions_json"
        exit 1
    fi

    # 构建当前版本映射（主版本 -> 完整版本号）
    declare -A current_versions
    for ver in $versions; do
        full=$(jq -r ".[\"$ver\"].version" "$versions_json")
        current_versions["$ver"]="$full"
    done

    # 读取已处理版本记录（格式：主版本:完整版本号）
    declare -A processed_versions
    if [ -f "$PROCESSED_FILE" ]; then
        while IFS=: read -r major full; do
            processed_versions["$major"]="$full"
        done < "$PROCESSED_FILE"
    fi

    # 读取忽略版本列表
    declare -A ignore_versions
    if [ -f "$IGNORE_FILE" ]; then
        while IFS= read -r major; do
            ignore_versions["$major"]=1
        done < "$IGNORE_FILE"
    fi

    # 确定需要构建的版本
    to_build=()
    for ver in "${!current_versions[@]}"; do
        # 检查是否被忽略
        if [ -n "${ignore_versions[$ver]}" ]; then
            log "Version $ver is in ignore list, skipping"
            continue
        fi
        current_full="${current_versions[$ver]}"
        old_full="${processed_versions[$ver]}"
        if [ -z "$old_full" ]; then
            log "New version $ver ($current_full) detected, will build"
            to_build+=("$ver")
        elif [ "$old_full" != "$current_full" ]; then
            log "Version $ver updated from $old_full to $current_full, will rebuild"
            to_build+=("$ver")
        else
            log "Version $ver already up-to-date ($current_full), skipping"
        fi
    done

    if [ ${#to_build[@]} -eq 0 ]; then
        log "No versions need building."
        exit 0
    fi

    # 构建每个需要更新的版本
    for ver in "${to_build[@]}"; do
        log "Processing version $ver (${current_versions[$ver]})"
        ./process_version.sh "$ver"
        # 更新记录文件（删除旧记录再追加）
        sed -i "/^$ver:/d" "$PROCESSED_FILE" 2>/dev/null || true
        echo "$ver:${current_versions[$ver]}" >> "$PROCESSED_FILE"
    done

    # Git 提交（可选）
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$PROCESSED_FILE" "$versions_json" template/ 2>/dev/null || true
        if ! git diff --cached --quiet; then
            git config user.name "CI Bot" || true
            git config user.email "ci@loongson.cn" || true
            git commit -m "Update Ruby images: ${to_build[*]}" || true
            git pull --rebase || true
            git push origin main || true
        fi
    fi

    log "CI finished."
}

main
