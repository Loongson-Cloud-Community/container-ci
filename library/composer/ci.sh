#!/bin/bash
# 注意：这里去掉 -e，我们手动处理错误
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"
VERSIONS_JSON="${SCRIPT_DIR}/versions.json"

# 导入公共函数
source "${SCRIPT_DIR}/lib.sh"

# 配置
GIT_USER_NAME="Huang Yang"
GIT_USER_EMAIL="huangyang@loongson.cn"
GIT_BRANCH="main"

# 检查版本是否已处理
is_version_processed() {
    local full_version="$1"
    grep -Fxq "$full_version" "$PROCESSED_FILE" 2>/dev/null
}

# 记录已处理的版本
mark_version_processed() {
    local full_version="$1"
    echo "$full_version" >> "$PROCESSED_FILE"
    log "Marked $full_version as processed"
}

# Git 提交变更
git_commit_changes() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log "Not a git repository, skipping commit"
        return 0
    fi
    
    git add "$PROCESSED_FILE" "$VERSIONS_JSON" template/ 2>/dev/null || true
    if git diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi
    
    git config user.name "$GIT_USER_NAME" || true
    git config user.email "$GIT_USER_EMAIL" || true
    
    local version_list=$(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$VERSIONS_JSON" | tr '\n' ' ')
    local commit_msg="ci: update Composer images - $version_list"
    
    log "Committing changes..."
    git commit -m "$commit_msg" || true
    git pull --rebase origin "$GIT_BRANCH" || log "WARNING: git pull failed"
    git push origin "$GIT_BRANCH" || log "WARNING: git push failed"
    
    log "Changes committed and pushed"
}

# 显示版本信息
show_version_info() {
    log "========== Version Info =========="
    jq -r 'to_entries[] | "\(.key) -> \(.value)"' "$VERSIONS_JSON" | while read line; do
        log "$line"
    done
    log "=================================="
}

# 主函数
main() {
    log "========== Composer Docker CI Started =========="
    
    check_dependencies
    
    # 确保 processed_versions.txt 存在
    if [ ! -f "$PROCESSED_FILE" ]; then
        touch "$PROCESSED_FILE"
        log "Created $PROCESSED_FILE"
    fi
    
    # 获取最新版本
    log "Step 1: Fetching latest versions..."
    ./fetch_versions.sh || die "fetch_versions.sh failed"
    
    # 显示版本信息
    show_version_info
    
    # 获取所有版本（按版本号排序）
    local versions
    versions="$(jq -r 'keys[]' "$VERSIONS_JSON" 2>/dev/null | sort -V || true)"
    
    if [ -z "$versions" ]; then
        die "No versions found in $VERSIONS_JSON"
    fi
    
    # 构建待处理列表
    local to_build=()
    
    log "Step 2: Checking which versions need to be built..."
    
    # 先检查所有版本，收集需要构建的
    for ver in $versions; do
        local full_version
        full_version="$(jq -r ".\"$ver\"" "$VERSIONS_JSON")"
        
        if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
            log "WARNING: Skipping $ver due to missing version"
            continue
        fi
        
        if is_version_processed "$full_version"; then
            log "SKIP: Version $ver ($full_version) already built"
        else
            log "TODO: Version $ver ($full_version) needs to be built"
            to_build+=("$ver:$full_version")
        fi
    done
    
    # 显示统计信息
    local total_versions=$(echo "$versions" | wc -l)
    local need_build=${#to_build[@]}
    
    log "=========================================="
    log "Total versions found: $total_versions"
    log "Need to build: $need_build"
    
    if [ $need_build -eq 0 ]; then
        log "All versions are already built, nothing to do."
        log "========== CI Completed =========="
        exit 0
    fi
    
    log "Versions to build:"
    for item in "${to_build[@]}"; do
        log "  - $item"
    done
    log "=========================================="
    
    # 处理每个需要构建的版本
    log "Step 3: Building versions..."
    local processed_count=0
    local failed_count=0
    local current_index=0
    local total_items=${#to_build[@]}
    
    # 使用 while 循环，确保不会因为 set -e 而退出
    while [ $current_index -lt $total_items ]; do
        local item="${to_build[$current_index]}"
        local ver="${item%:*}"
        local full_version="${item#*:}"
        
        log "--------------------------------------------------"
        log "Processing item $((current_index + 1)) of $total_items: $ver ($full_version)"
        
        # 在子shell中执行，捕获所有输出和退出码
        local build_output
        local exit_code
        
        # 使用临时文件捕获输出
        local temp_output=$(mktemp)
        
        # 执行构建
        (
            set -e
            ./process_version.sh "$ver"
        ) > "$temp_output" 2>&1
        exit_code=$?
        
        # 显示输出
        if [ -s "$temp_output" ]; then
            cat "$temp_output"
        fi
        rm -f "$temp_output"
        
        if [ $exit_code -eq 0 ]; then
            mark_version_processed "$full_version"
            ((processed_count++))
            log "SUCCESS: Version $ver ($full_version) built successfully"
        else
            ((failed_count++))
            log "ERROR: Version $ver ($full_version) build failed (exit code: $exit_code)"
            # 继续处理其他版本
        fi
        
        ((current_index++))
    done
    
    # 提交变更
    log "Step 4: Committing changes..."
    git_commit_changes
    
    log "========== CI Completed =========="
    log "Summary: Processed: $processed_count, Failed: $failed_count"
    log "Total versions: $total_versions"
    
    if [ $failed_count -gt 0 ]; then
        log "WARNING: $failed_count version(s) failed to build"
        return 1
    fi
    
    return 0
}

main "$@"
