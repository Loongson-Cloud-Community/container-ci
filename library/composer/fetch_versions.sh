#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
VERSIONS_JSON="${SCRIPT_DIR}/versions.json"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"

# 导入公共函数
source "${SCRIPT_DIR}/lib.sh"

# 配置
UPSTREAM_REPO="https://github.com/composer/docker.git"
UPSTREAM_BRANCH="main"

sync_upstream() {
    log "Syncing upstream repository to template/..."
    
    # 创建临时目录
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    # 克隆上游仓库（浅克隆，只获取最新代码）
    git clone --depth 1 --branch "$UPSTREAM_BRANCH" "$UPSTREAM_REPO" repo || die "Failed to clone upstream"
    
    # 查找所有包含 COMPOSER_VERSION 的 Dockerfile
    local dockerfiles=$(find repo -name "Dockerfile" -exec grep -l "COMPOSER_VERSION" {} \;)
    if [ -z "$dockerfiles" ]; then
        die "No Dockerfiles with COMPOSER_VERSION found"
    fi
    
    # 清空旧的 versions.json
    > "$VERSIONS_JSON"
    echo "{" >> "$VERSIONS_JSON"
    local first=true
    
    # 使用数组存储已处理的大版本，避免重复
    declare -A processed_majors
    
    for dockerfile in $dockerfiles; do
        log "Processing: $dockerfile"
        
        # 提取 COMPOSER_VERSION（格式: ENV COMPOSER_VERSION=2.2.29）
        local full_version=$(grep -E '^ENV COMPOSER_VERSION' "$dockerfile" | awk -F'=' '{print $2}' | tr -d ' \r')
        if [ -z "$full_version" ]; then
            log "WARNING: No COMPOSER_VERSION found in $dockerfile, skipping..."
            continue
        fi
        
        # 提取大版本号（如 2.2）
        local major_version=$(echo "$full_version" | grep -oE '^[0-9]+\.[0-9]+')
        if [ -z "$major_version" ]; then
            log "WARNING: Cannot extract major version from $full_version, skipping..."
            continue
        fi
        
        # 确定目标目录名
        local src_dir=$(dirname "$dockerfile")
        local dir_name=$(basename "$src_dir")
        
        # 如果目录名是有效的版本格式，使用它；否则使用提取的大版本号
        local target_dir="$major_version"
        if [[ "$dir_name" =~ ^[0-9]+\.[0-9]+$ ]] && [ -n "$dir_name" ]; then
            target_dir="$dir_name"
        fi
        
        # 检查是否已处理过这个大版本
        if [ -n "${processed_majors[$target_dir]}" ]; then
            log "INFO: Major version $target_dir already processed, skipping duplicate..."
            continue
        fi
        processed_majors[$target_dir]=1
        
        log "Found: $target_dir -> $full_version"
        
        # 创建模板目录
        local target_path="${TEMPLATE_DIR}/${target_dir}"
        mkdir -p "$target_path"
        
        # 拷贝 Dockerfile
        cp "$dockerfile" "$target_path/"
        log "Copied Dockerfile to $target_path/"
        
        # 拷贝 docker-entrypoint.sh（如果存在）
        local entrypoint_src="${src_dir}/docker-entrypoint.sh"
        if [ -f "$entrypoint_src" ]; then
            cp "$entrypoint_src" "$target_path/"
            log "Copied docker-entrypoint.sh to $target_path/"
        else
            log "WARNING: docker-entrypoint.sh not found in $src_dir"
        fi
        
        # 写入 versions.json
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$VERSIONS_JSON"
        fi
        echo "  \"$target_dir\": \"$full_version\"" >> "$VERSIONS_JSON"
    done
    
    echo "}" >> "$VERSIONS_JSON"
    
    # 清理临时目录
    cd "$SCRIPT_DIR"
    rm -rf "$tmp_dir"
    
    log "Generated $VERSIONS_JSON with $(jq '. | length' "$VERSIONS_JSON") version(s)"
}

# 确保 processed_versions.txt 存在
ensure_processed_file() {
    if [ ! -f "$PROCESSED_FILE" ]; then
        touch "$PROCESSED_FILE"
        log "Created $PROCESSED_FILE"
    fi
}

main() {
    check_dependencies
    ensure_processed_file
    sync_upstream
    log "fetch_versions.sh completed successfully"
}

main "$@"
