#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='drupal'

# 从完整版本号提取大版本（10.6.8 -> 10.6）
get_major_from_full() {
    local full_version="$1"
    echo "$full_version" | grep -oE '^[0-9]+\.[0-9]+'
}

# 获取该大版本支持的所有 PHP 版本
get_php_versions() {
    local major="$1"
    jq -r ".\"$major\".phpVersions[]" ./template/versions.json
}

# 获取该大版本的所有变体
get_variants() {
    local major="$1"
    jq -r ".\"$major\".variants[]" ./template/versions.json
}

# 构建并推送单个变体
build_and_push_variant() {
    local major="$1"
    local full_version="$2"
    local php_version="$3"
    local variant="$4"
    
    local build_dir="./template/$major/php$php_version/$variant"
    
    if [ ! -d "$build_dir" ]; then
        log WARN "Build directory not found: $build_dir, skipping..."
        return 0
    fi
    
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    
    # 构建标签：完整版本-php版本-变体
    local specific_tag="${full_version}-php${php_version}-${variant}"
    
    log INFO "Building ${image_name}:${specific_tag} from $build_dir"
    docker build -t "${image_name}:${specific_tag}" "$build_dir" || {
        log ERROR "Build failed for ${image_name}:${specific_tag}"
        return 1
    }

    docker push "${image_name}:${specific_tag}" || {
        log ERROR "Push failed for ${image_name}:${specific_tag}"
        return 1
    }
    log INFO "Pushed ${image_name}:${specific_tag}"

    # 生成别名
    local aliases=()
    
    # 1. 大版本-php版本-变体
    aliases+=("${major}-php${php_version}-${variant}")
    
    # 2. 完整版本-变体（不带php版本，适用于默认PHP版本）
    local default_php=$(get_php_versions "$major" | head -1)
    if [ "$php_version" == "$default_php" ]; then
        aliases+=("${full_version}-${variant}")
        aliases+=("${major}-${variant}")
    fi
    
    # 3. 如果是 apache 变体，生成无变体标签（官方风格）
    if [[ "$variant" == "apache-forky" ]] || [[ "$variant" == "apache"* ]]; then
        if [ "$php_version" == "$default_php" ]; then
            aliases+=("${full_version}")
            aliases+=("${major}")
        fi
        aliases+=("${full_version}-apache")
        aliases+=("${major}-apache")
    fi
    
    # 4. 如果是 fpm 变体
    if [[ "$variant" == "fpm-forky" ]] || [[ "$variant" == "fpm"* ]]; then
        if [[ "$variant" != *"alpine"* ]]; then
            aliases+=("${full_version}-fpm")
            aliases+=("${major}-fpm")
        fi
    fi
    
    # 5. Alpine 变体
    if [[ "$variant" == *"alpine"* ]]; then
        local alpine_ver="${variant#*-}"
        aliases+=("${full_version}-${alpine_ver}")
        aliases+=("${major}-${alpine_ver}")
        # 如果是最新 PHP 版本，生成无 php 版本的 alpine 标签
        if [ "$php_version" == "$default_php" ]; then
            aliases+=("${full_version}-alpine")
            aliases+=("${major}-alpine")
        fi
    fi
    
    # 6. 最新大版本推 latest
    local latest_major=$(jq -r 'keys[] | select(contains("-rc") | not)' ./template/versions.json | sort -V | tail -1)
    if [ "$major" == "$latest_major" ] && [ "$php_version" == "$default_php" ]; then
        if [[ "$variant" == "apache-forky" ]] || [[ "$variant" == "apache"* ]]; then
            aliases+=("latest")
        fi
    fi

    # 去重并推送所有别名
    for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
        docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
        docker push "${image_name}:${alias}"
        log INFO "Pushed alias: ${alias}"
    done
}

# 处理一个完整版本
process_version() {
    local full_version="$1"
    local major=$(get_major_from_full "$full_version")
    
    if [ -z "$major" ]; then
        log ERROR "Cannot extract major version from $full_version"
        return 1
    fi
    
    if [ ! -d "./template/$major" ]; then
        log ERROR "template/$major directory not found"
        return 1
    fi
    
    log INFO "Processing $major (full version: $full_version)"
    
    local php_versions=$(get_php_versions "$major")
    local variants=$(get_variants "$major")
    
    for php_version in $php_versions; do
        for variant in $variants; do
            build_and_push_variant "$major" "$full_version" "$php_version" "$variant"
        done
    done
}

process() {
    local full_version="$1"
    process_version "$full_version"
}

process "$1"
