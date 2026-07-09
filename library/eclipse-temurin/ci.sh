#!/bin/bash
set -eo pipefail

# ============================================================
# 主控脚本：协调 Eclipse Temurin 镜像的构建流程
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"

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
    command -v jq >/dev/null 2>&1 || die "jq is required"
    command -v git >/dev/null 2>&1 || die "git is required"
}

# ---------- 获取所有主版本号 ----------
get_all_majors() {
    jq -r 'keys[]' "$VERSIONS_JSON" 2>/dev/null || true
}

# ---------- 检查版本是否已构建 ----------
is_version_built() {
    local full_version="$1"
    grep -Fxq "$full_version" "$PROCESSED_FILE" 2>/dev/null
}

# ---------- 提交变更到 Git ----------
git_commit_changes() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log "Not a git repository, skipping commit"
        return 0
    fi

    git reset --quiet
    # 添加所有模板目录下的文件（Dockerfile、配置文件等）
    git add template/ "$PROCESSED_FILE" 2>/dev/null || true

    if ! git diff --cached --quiet; then
        git config user.name "Huang Yang" || true
        git config user.email "huangyang@loongson.cn" || true
        git commit -m "Update Eclipse Temurin images" || true
        git pull --rebase || true
        git push origin main || true
        log "Changes committed and pushed"
    else
        log "No changes to commit"
    fi
}

# ---------- 主函数 ----------
main() {
    check_dependencies

    log "Fetching latest Temurin versions..."
    ./fetch_versions.sh || die "fetch_versions.sh failed"

    local versions
    versions="$(get_all_majors)"
    if [ -z "$versions" ]; then
        die "No versions found in $VERSIONS_JSON"
    fi

    for ver in $versions; do
        local full_version
        full_version="$(jq -r ".\"$ver\".version" "$VERSIONS_JSON")"
        if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
            log "WARNING: Skipping $ver due to missing version"
            continue
        fi
        if is_version_built "$full_version"; then
            log "Version $ver ($full_version) already built, skipping"
            continue
        fi
        log "Processing version $ver ($full_version)"
        ./process_version.sh "$ver" || die "process_version.sh failed for $ver"
        echo "$full_version" >> "$PROCESSED_FILE"
    done

    git_commit_changes
    log "CI finished successfully"
}

main "$@"
