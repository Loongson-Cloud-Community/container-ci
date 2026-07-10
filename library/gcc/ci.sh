#!/bin/bash
set -eo pipefail

# ============================================================
# 主控脚本：协调 GCC 镜像的构建流程
# 功能：
#   1. 生成 versions.json 和 Dockerfile
#   2. 遍历所有主版本，调用 process_version.sh 构建
#   3. 提交 Git 变更
# 注意：不生成 latest 标签
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
    command -v docker >/dev/null 2>&1 || die "docker is required"
}

# ---------- 生成版本和 Dockerfile ----------
generate_all_versions() {
    log "Generating versions.json and Dockerfiles..."
    cd "${SCRIPT_DIR}/template" || die "Cannot enter template directory"
    ./update.sh || die "update.sh failed"
    cd "${SCRIPT_DIR}" || die "Cannot return to script directory"
}

# ---------- 获取所有主版本 ----------
get_all_majors() {
    if [ ! -f "$VERSIONS_JSON" ]; then
        die "$VERSIONS_JSON not found"
    fi
    jq -r 'keys[]' "$VERSIONS_JSON" 2>/dev/null | sort -n || true
}

# ---------- 检查版本是否已构建 ----------
is_version_built() {
    local gcc_version="$1"
    grep -Fxq "$gcc_version" "$PROCESSED_FILE" 2>/dev/null
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
    git commit -m "Update GCC images" || true
    git pull --rebase || true
    git push origin main || true
    log "Changes committed and pushed"
}

# ---------- 主函数 ----------
main() {
    check_dependencies

    generate_all_versions

    local versions
    versions="$(get_all_majors)"
    if [ -z "$versions" ]; then
        die "No versions found in $VERSIONS_JSON"
    fi

    for ver in $versions; do
        local dockerfile="${SCRIPT_DIR}/template/$ver/Dockerfile"
        if [ ! -f "$dockerfile" ]; then
            log "WARNING: $dockerfile not found, skipping $ver"
            continue
        fi
        local gcc_version
        gcc_version="$(grep -E '^ENV GCC_VERSION' "$dockerfile" | awk '{print $3}')"
        if [ -z "$gcc_version" ]; then
            log "WARNING: Cannot get GCC_VERSION for $ver, skipping"
            continue
        fi
        if is_version_built "$gcc_version"; then
            log "Version $ver ($gcc_version) already built, skipping"
            continue
        fi
        log "Building version $ver ($gcc_version)..."
        "${SCRIPT_DIR}/process_version.sh" "$ver" || die "process_version.sh failed for $ver"
        echo "$gcc_version" >> "$PROCESSED_FILE"
    done

    git_commit_changes

    log "CI finished successfully"
}

main "$@"
