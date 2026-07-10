#!/bin/bash
set -eo pipefail

# ============================================================
# 主控脚本：构建 Traefik 最新版本镜像
# 功能：
#   1. 获取最新版本号
#   2. 检查是否已构建，未构建则调用 process_version.sh
#   3. 提交 Git 变更
# 注意：不生成 latest 标签
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"

# ---------- 日志函数 ----------
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
    command -v git >/dev/null 2>&1 || die "git is required"
    command -v jq >/dev/null 2>&1 || die "jq is required"
    command -v docker >/dev/null 2>&1 || die "docker is required"
}

# ---------- 获取最新版本号 ----------
get_latest_version() {
    ./fetch_versions.sh || die "fetch_versions.sh failed"
}

# ---------- 检查版本是否已构建 ----------
is_version_built() {
    local version="$1"
    grep -Fxq "$version" "$PROCESSED_FILE" 2>/dev/null
}

# ---------- 提交变更到 Git ----------
git_commit_changes() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log "Not a git repository, skipping commit"
        return 0
    fi

    git reset --quiet
    git add "$PROCESSED_FILE" template/ 2>/dev/null || true

    if git diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi

    git config user.name "Huang Yang" || true
    git config user.email "huangyang@loongson.cn" || true
    git commit -m "Update Traefik to $1" || true
    git pull --rebase || true
    git push origin main || true
    log "Changes committed and pushed"
}

# ---------- 主函数 ----------
main() {
    check_dependencies

    local version
    version="$(get_latest_version)"
    if [ -z "$version" ]; then
        die "Failed to get latest version"
    fi
    log "Latest Traefik version: $version"

    if is_version_built "$version"; then
        log "Version $version already built, skipping"
        exit 0
    fi

    log "Processing version $version..."
    ./process_version.sh "$version" || die "process_version.sh failed"

    echo "$version" >> "$PROCESSED_FILE"
    log "Recorded $version in $PROCESSED_FILE"

    #git_commit_changes "$version"

    log "CI finished successfully"
}

main "$@"
