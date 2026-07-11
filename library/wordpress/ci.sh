#!/bin/bash
set -eo pipefail

# ============================================================
# WordPress CI 主控脚本
# 功能：
#   1. 尝试更新版本（若失败则使用缓存）
#   2. 依次处理 latest 和 cli 系列
#   3. 记录已构建版本，提交变更
#   4. template 目录内容来自:https://github.com/docker-library/wordpress.git
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"
IGNORE_FILE="${SCRIPT_DIR}/ignore_versions.txt"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
VERSIONS_JSON="${TEMPLATE_DIR}/versions.json"
BACKUP_JSON="${TEMPLATE_DIR}/versions.json.bak"

# ---------- 日志 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ---------- 错误处理 ----------
die() {
    log "ERROR: $*" >&2
    exit 1
}

# ---------- 检查依赖 ----------
check_dependencies() {
    command -v jq >/dev/null 2>&1 || die "jq is required"
    command -v docker >/dev/null 2>&1 || die "docker is required"
    command -v git >/dev/null 2>&1 || die "git is required"
}

# ---------- 更新版本（带缓存和重试） ----------
update_versions() {
    cd "$TEMPLATE_DIR" || die "Cannot enter template directory"

    # 备份当前 versions.json（如果存在）
    if [ -f "$VERSIONS_JSON" ]; then
        cp "$VERSIONS_JSON" "$BACKUP_JSON"
    fi

    local max_attempts=3
    local attempt=1
    local success=0

    while [ $attempt -le $max_attempts ] && [ $success -eq 0 ]; do
        log "Running update.sh (attempt $attempt)..."
        if ./update.sh 2>&1; then
            success=1
            log "update.sh succeeded"
            cp "$VERSIONS_JSON" "$BACKUP_JSON"
        else
            local exit_code=$?
            log "update.sh failed with exit code $exit_code"
            if [ $attempt -lt $max_attempts ]; then
                log "Retrying in 10 seconds..."
                sleep 10
            fi
            ((attempt++))
        fi
    done

    cd - >/dev/null

    if [ $success -eq 0 ]; then
        log "All update attempts failed. Attempting to use cached versions.json..."
        if [ -f "$BACKUP_JSON" ]; then
            cp "$BACKUP_JSON" "$VERSIONS_JSON"
            log "Restored cached versions.json"
        else
            die "No cached versions.json available and update.sh failed"
        fi
    fi
}

# ---------- 获取版本号 ----------
get_version() {
    local series="$1"
    jq -r ".[\"$series\"].version" "$VERSIONS_JSON" 2>/dev/null || echo ""
}

# ---------- 检查是否忽略 ----------
is_ignored() {
    local series="$1"
    grep -Fxq "$series" "$IGNORE_FILE" 2>/dev/null
}

# ---------- 检查是否已构建 ----------
is_processed() {
    local series="$1"
    local version="$2"
    grep -q "^$series:$version$" "$PROCESSED_FILE" 2>/dev/null
}

# ---------- 记录已构建 ----------
record_processed() {
    local series="$1"
    local version="$2"
    sed -i "/^$series:/d" "$PROCESSED_FILE" 2>/dev/null || true
    echo "$series:$version" >> "$PROCESSED_FILE"
}

# ---------- 提交 Git 变更（统一命名） ----------
git_commit_changes() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        return 0
    fi
    git reset --quiet
    git add "$PROCESSED_FILE" "$VERSIONS_JSON" "$TEMPLATE_DIR" 2>/dev/null || true
    if git diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi
    git config user.name "Huang Yang" || true
    git config user.email "huangyang@loongson.cn" || true
    git commit -m "Update WordPress images" || true
    git pull --rebase || true
    git push origin main || true
    log "Changes committed and pushed"
}

# ---------- 主函数 ----------
main() {
    check_dependencies

    update_versions

    local series_list=("latest" "cli")
    for series in "${series_list[@]}"; do
        local current_version
        current_version="$(get_version "$series")"
        if [ -z "$current_version" ] || [ "$current_version" = "null" ]; then
            log "ERROR: Cannot get version for $series, skipping"
            continue
        fi

        if is_ignored "$series"; then
            log "Series $series is in ignore list, skipping"
            continue
        fi

        if is_processed "$series" "$current_version"; then
            log "Series $series already up-to-date ($current_version), skipping"
            continue
        fi

        log "Processing series $series ($current_version)"
        ./process_version.sh "$series" || die "process_version.sh failed for $series"
        record_processed "$series" "$current_version"
    done

    git_commit_changes
    log "CI finished successfully"
}

main "$@"
