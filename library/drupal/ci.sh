#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$(dirname $0)/lib.sh"

readonly ORG='library'
readonly PROJ='drupal'
readonly UPSTREAM_REPO='https://github.com/docker-library/drupal.git'
readonly TEMPLATE_DIR='./template'

# Git 提交
git_commit() {
    local versions="$1"
    git add .
    git config user.name "huangyang"
    git config user.email "huangyang@loongson.cn"
    git commit -m "$ORG $PROJ: Add versions: $versions" || true
    git pull --rebase || true
    git push origin main || true
}

# 应用本地修改（基础镜像地址、变体名称等）
apply_local_patches() {
    local work_dir="$1"
    log INFO "Applying local modifications to template..."
    
    pushd "$work_dir" >/dev/null
    
    # 1. 修改 Dockerfile.template：将 php 基础镜像改为私有仓库
    if [ -f "Dockerfile.template" ]; then
        sed -i 's|FROM php:{{ env.phpVersion }}-{{ env.variant }}|FROM lcr.loongnix.cn/library/php:{{ env.phpVersion }}-{{ env.variant }}|g' Dockerfile.template
        log INFO "Modified Dockerfile.template: php base image -> lcr.loongnix.cn/library/php"
    fi
    
    # 2. 修改 Dockerfile.template：将 composer 替换为 curl 下载方式
    if [ -f "Dockerfile.template" ]; then
        # 删除 COPY --from=composer 行
        sed -i '/COPY --from=composer:/d' Dockerfile.template
        
        # 在 ENV DRUPAL_VERSION 之前添加 Composer 安装
        sed -i '/^ENV DRUPAL_VERSION/i \
# 安装 Composer（通过官方 installer 安装）\nRUN set -eux; \\\n    curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer; \\\n    chmod +x /usr/local/bin/composer\n' Dockerfile.template
        
        log INFO "Modified Dockerfile.template: composer installed via curl"
    fi
    
    # 3. 修改 versions.sh：将 trixie/bookworm 替换为 forky
    if [ -f "versions.sh" ]; then
        sed -i 's/"trixie",/"forky",/g' versions.sh
        sed -i 's/"bookworm",/"forky",/g' versions.sh
        log INFO "Modified versions.sh: trixie/bookworm -> forky"
    fi
    
    popd >/dev/null
    
    log INFO "Local modifications applied"
}

# 更新 template 目录
update_template() {
    log INFO "Updating template from upstream..."
    
    # 1. 克隆上游仓库到临时目录
    local tmp_dir=$(mktemp -d)
    log INFO "Cloning to temporary directory: $tmp_dir"
    git clone --depth=1 "$UPSTREAM_REPO" "$tmp_dir" || {
        log ERROR "Failed to clone upstream repository"
        rm -rf "$tmp_dir"
        exit 1
    }
    
    # 2. 在临时目录中应用本地修改
    apply_local_patches "$tmp_dir"
    
    # 3. 执行 update.sh 生成 versions.json
    if [ -x "$tmp_dir/update.sh" ]; then
        pushd "$tmp_dir" >/dev/null
        log INFO "Running update.sh..."
        ./update.sh
        popd >/dev/null
    else
        log ERROR "update.sh not found or not executable"
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    # 4. 执行 apply-templates.sh 生成 Dockerfile
    if [ -x "$tmp_dir/apply-templates.sh" ]; then
        pushd "$tmp_dir" >/dev/null
        log INFO "Running apply-templates.sh..."
        ./apply-templates.sh
        popd >/dev/null
    else
        log ERROR "apply-templates.sh not found or not executable"
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    # 5. 清空并拷贝处理后的内容到 template 目录
    log INFO "Copying processed content to $TEMPLATE_DIR..."
    rm -rf "$TEMPLATE_DIR"
    mkdir -p "$TEMPLATE_DIR"
    cp -r "$tmp_dir/." "$TEMPLATE_DIR/"
    
    # 6. 清理临时目录
    rm -rf "$tmp_dir"
    
    log INFO "Template updated successfully"
}

main() {
    check_dependencies
    
    # 0. 更新 template（从上游克隆到临时目录 → 应用修改 → 拷贝到 template）
    update_template
    
    # 1. 获取需要构建的版本
    IFS=$'\n' versions=($(./fetch_versions.sh))
    
    if [[ -z "$versions" ]]; then
        log INFO "No versions need updating"
        return 0
    fi
    
    log INFO "Versions needing update: ${versions[@]}"
    
    # 2. 执行构建
    for full_version in "${versions[@]}"; do
        log INFO "Process version $full_version"
        ./process_version.sh "${full_version}"
        update_versions_file "processed_versions.txt" "${full_version}"
    done
    
    # 3. 提交变更
    git_commit "${versions[*]}"
    
    log INFO "All Versions:\n$(cat processed_versions.txt)"
}

main
