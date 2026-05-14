#!/bin/bash
set -eo pipefail

PROCESSED_FILE="processed_versions.txt"
VERSIONS_JSON="template/versions.json"

# Git 配置（请根据你的环境调整）
GIT_USER_NAME="Huang Yang"
GIT_USER_EMAIL="huangyang@loongson.cn"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

git_commit() {
    local message="$1"
    git add "$PROCESSED_FILE" "$VERSIONS_JSON" 2>/dev/null || true
    # 同时添加可能更新的 template/ 下的 Dockerfile（若有生成新版本）
    git add template/ 2>/dev/null || true
    if git diff --cached --quiet; then
        log "No changes to commit."
        return 0
    fi
    git config user.name "$GIT_USER_NAME"
    git config user.email "$GIT_USER_EMAIL"
    git commit -m "$message"
    git pull --rebase || true
    git push origin main || log "Push failed, please check permissions."
}

main() {
    # 1. 获取最新版本
    log "Fetching latest OpenJDK versions..."
    ./fetch_versions.sh

    # 2. 生成 Dockerfile
    log "Generating Dockerfiles..."
    cd template
    ./apply-templates.sh
    cd ..

    # 3. 读取当前版本映射
    declare -A current_versions
    for major in $(jq -r 'keys[]' "$VERSIONS_JSON"); do
        current_versions["$major"]=$(jq -r ".[\"$major\"].version" "$VERSIONS_JSON")
    done

    # 4. 读取已处理版本
    declare -A processed_versions
    if [ -f "$PROCESSED_FILE" ]; then
        while IFS=: read -r major version; do
            processed_versions["$major"]="$version"
        done < "$PROCESSED_FILE"
    fi

    # 5. 确定需要构建的版本
    to_build=()
    for major in "${!current_versions[@]}"; do
        old_ver="${processed_versions[$major]}"
        new_ver="${current_versions[$major]}"
        if [ -z "$old_ver" ]; then
            log "New version: $major -> $new_ver"
            to_build+=("$major")
        elif [ "$old_ver" != "$new_ver" ]; then
            log "Version update: $major from $old_ver to $new_ver"
            to_build+=("$major")
        else
            log "Version $major already at $new_ver, skipping"
        fi
    done

    if [ ${#to_build[@]} -eq 0 ]; then
        log "No versions need building."
        exit 0
    fi

    # 6. 构建并推送
    for major in "${to_build[@]}"; do
        log "Building and pushing $major (${current_versions[$major]})"
        ./process_version.sh "$major"
        # 更新记录文件
        sed -i "/^$major:/d" "$PROCESSED_FILE" 2>/dev/null || true
        echo "$major:${current_versions[$major]}" >> "$PROCESSED_FILE"
    done

    # 7. 提交 Git
    git_commit "Update OpenJDK versions: ${to_build[*]} to ${current_versions[*]}"

    log "CI completed."
}

main
