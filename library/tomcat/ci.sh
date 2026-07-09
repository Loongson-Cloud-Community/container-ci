#!/bin/bash
set -Eeuo pipefail

# ============================================================
# 主控脚本：协调整个 CI 流程
# 功能：
#   1. 更新版本信息并生成 Dockerfile
#   2. 遍历所有大版本，调用 process_version.sh 构建
#   3. 提交 Git 变更
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"   # 统一放在 template 下

# ---------- 日志函数 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ---------- 生成版本及 Dockerfile ----------
generate_all_versions() {
    log "Generating versions.json and Dockerfiles..."
    cd "${SCRIPT_DIR}/template"
    ./versions.sh   # 这个脚本会生成 versions.json 到当前目录（即 template/）
    ./apply-templates.sh
    cd "${SCRIPT_DIR}"
}

# ---------- 获取所有大版本 ----------
get_all_majors() {
    jq -r 'keys[]' "$VERSIONS_JSON" 2>/dev/null || true
}

# ---------- 检查版本是否已构建 ----------
is_version_built() {
    local full_version="$1"
    grep -Fxq "$full_version" "$PROCESSED_FILE" 2>/dev/null
}

# ---------- Git 提交 ----------
git_commit_changes() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        return 0
    fi
    git reset --quiet
    git add "$PROCESSED_FILE" "$VERSIONS_JSON" 2>/dev/null || true
    find template -type f -name "Dockerfile" 2>/dev/null | xargs git add 2>/dev/null || true
    if git diff --cached --quiet; then
        return 0
    fi
    git config user.name "Huang Yang" || true
    git config user.email "huangyang@loongson.cn" || true
    local commit_msg="Update Tomcat: $(jq -r 'to_entries[] | "\(.key)=\(.value.version)"' "$VERSIONS_JSON" | tr '\n' ' ')"
    git commit -m "$commit_msg" || true
    git pull --rebase || true
    git push origin main || true
}

# ---------- 主函数 ----------
main() {
    # 1. 生成版本和 Dockerfile
    generate_all_versions

    # 2. 检查 versions.json 是否存在
    if [ ! -f "$VERSIONS_JSON" ]; then
        log "ERROR: $VERSIONS_JSON not found"
        exit 1
    fi

    # 3. 读取所有大版本
    mapfile -t VERSIONS < <(get_all_majors)
    if [ ${#VERSIONS[@]} -eq 0 ]; then
        log "ERROR: No versions found in $VERSIONS_JSON"
        exit 1
    fi

    # 4. 依次构建每个版本
    for ver in "${VERSIONS[@]}"; do
        full_version="$(jq -r ".\"$ver\".version" "$VERSIONS_JSON")"
        if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
            log "WARNING: Skipping $ver due to missing version"
            continue
        fi
        if is_version_built "$full_version"; then
            log "Version $ver ($full_version) already built, skipping"
            continue
        fi
        log "Building new version $ver ($full_version)"
        "${SCRIPT_DIR}/process_version.sh" "$ver"
        echo "$full_version" >> "$PROCESSED_FILE"
    done

    # 5. Git 提交
    git_commit_changes

    log "CI finished successfully"
}

main "$@"
