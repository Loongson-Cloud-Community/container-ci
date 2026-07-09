#!/bin/bash
set -eo pipefail

# ============================================================
# 主控脚本：获取版本、构建镜像、提交变更
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"
VERSIONS_JSON="${SCRIPT_DIR}/versions.json"

# ---------- 日志函数 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ---------- 错误处理 ----------
die() {
    log "ERROR: $*" >&2
    exit 1
}

# ---------- 检查必要命令 ----------
check_dependencies() {
    command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
    command -v git >/dev/null 2>&1 || die "git is required but not installed"
}

# ---------- 获取所有大版本 ----------
get_major_versions() {
    if [ ! -f "$VERSIONS_JSON" ]; then
        die "versions.json not found"
    fi
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
    git add "$PROCESSED_FILE" "$VERSIONS_JSON" 2>/dev/null || true
    find template -type f \( -name "Dockerfile" -o -name "entrypoint.sh" -o -name "generate-jetty-start.sh" \) 2>/dev/null | xargs git add 2>/dev/null || true

    if git diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi

    git config user.name "Huang Yang" || true
    git config user.email "huangyang@loongson.cn" || true
    local commit_msg="Update Jetty images: $(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$VERSIONS_JSON" | tr '\n' ' ')"
    git commit -m "$commit_msg" || true
    git pull --rebase || true
    git push origin main || true
    log "Changes committed and pushed"
}

# ---------- 主函数 ----------
main() {
    check_dependencies

    # 1. 更新版本和 Dockerfile
    log "Fetching latest Jetty versions..."
    ./fetch_versions.sh || die "fetch_versions.sh failed"

    # 2. 读取所有大版本
    local VERSIONS
    VERSIONS="$(get_major_versions)"
    if [ -z "$VERSIONS" ]; then
        die "No versions found in $VERSIONS_JSON"
    fi

    # 3. 对每个版本调用 process_version.sh
    for ver in $VERSIONS; do
        local full_version
        full_version="$(jq -r ".\"$ver\"" "$VERSIONS_JSON")"
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

    # 4. Git 提交
    git_commit_changes

    log "CI finished successfully"
}

main "$@"
