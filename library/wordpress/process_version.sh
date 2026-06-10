#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="wordpress"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <series> (latest or cli)"
    exit 1
fi

series="$1"
versions_json="template/versions.json"

full_version=$(jq -r ".[\"$series\"].version" "$versions_json")
if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
    log "ERROR: Cannot find version for series $series"
    exit 1
fi
log "Building WordPress $series ($full_version)"

# 获取该系列下所有变体目录（由官方 apply-templates.sh 生成）
if [ ! -d "template/$series" ]; then
    log "ERROR: template/$series not found"
    exit 1
fi

# 查找所有 Dockerfile 所在的目录（深度为 2，如 latest/php8.2/apache）
find "template/$series" -name Dockerfile -type f | while read dockerfile; do
    build_dir=$(dirname "$dockerfile")
    # 相对路径，例如 "latest/php8.2/apache"
    rel_path="${build_dir#template/}"
    # 生成标签后缀：将路径中的 '/' 替换为 '-'，例如 "php8.2-apache"
    suffix=$(echo "$rel_path" | cut -d/ -f2- | tr '/' '-')
    # 对于 cli 系列，suffix 可能是 "php8.2"（因为 cli 下只有一层目录）
    # 需要特殊处理：若 series 为 cli，suffix 应为 "php8.2"
    if [ "$series" = "cli" ]; then
        suffix=$(basename "$build_dir")   # 例如 "php8.2"
    fi

    image_name="${REGISTRY}/${ORG}/${PROJ}"
    specific_tag="${full_version}-${suffix}"

    log "Building $image_name:$specific_tag from $build_dir"
    docker build --network host -t "${image_name}:${specific_tag}" "$build_dir" || {
        log "ERROR: Build failed for $rel_path"
        exit 1
    }

    log "Pushing $image_name:$specific_tag"
    docker push "${image_name}:${specific_tag}" || {
        log "ERROR: Push failed for $rel_path"
        exit 1
    }

    # 生成别名（根据官方 tag 规则）
    # 解析 suffix 中的信息，例如 "php8.2-apache", "php8.2-fpm", "php8.2-fpm-alpine"
    # 同时生成不带 PHP 版本的短标签（如 7.0.0-apache, 7.0-apache, 7-apache, apache, 7.0.0, 7.0, 7, latest）
    # 以及带 PHP 版本的短标签（如 7.0.0-php8.2-apache, 7.0-php8.2-apache, 7-php8.2-apache, php8.2-apache）
    major_minor=$(echo "$full_version" | cut -d. -f1,2)
    major=$(echo "$full_version" | cut -d. -f1)

    if [[ "$suffix" =~ ^php([0-9.]+)-(apache|fpm|fpm-alpine)$ ]]; then
        php_ver="${BASH_REMATCH[1]}"
        variant="${BASH_REMATCH[2]}"
        base_suffix="${suffix#*-}"   # apache, fpm, fpm-alpine
        # 带 PHP 版本的标签
        aliases=()
        aliases+=("${full_version}-${suffix}")
        aliases+=("${major_minor}-${suffix}")
        aliases+=("${major}-${suffix}")
        aliases+=("${suffix}")

        # 不带 PHP 版本的通用标签（只有默认 PHP 版本才生成？官方对所有 PHP 版本都生成无 php 版本的标签？实际上官方为每个 PHP 版本都生成独立的通用标签？）
        # 从官方列表看，7.0.0-apache 等标签对应的是默认 PHP 版本（通常是 8.3），而不是所有 PHP 版本。
        # 因此我们只对默认 PHP 版本（例如 8.3）生成通用标签。可以通过判断 php_ver 是否为 "8.3" 来决定。
        # 但为了简化，我们暂时只生成带 PHP 版本的标签，避免冲突。
        # 如果你希望生成通用标签，请告知默认 PHP 版本，我这里先不生成。
        
        # 另外，对于 apache 变体，还需要生成顶级版本标签（无变体后缀）
        # 官方只对默认 PHP 版本的 apache 变体生成 7.0.0, 7.0, 7, latest。
        if [ "$variant" = "apache" ] && [ "$php_ver" = "8.3" ]; then
            aliases+=("$full_version")
            aliases+=("$major_minor")
            aliases+=("$major")
            if [ "$series" = "latest" ]; then
                aliases+=("latest")
            fi
            # 同时生成通用变体标签（无 PHP 版本）
            aliases+=("${full_version}-${base_suffix}")
            aliases+=("${major_minor}-${base_suffix}")
            aliases+=("${major}-${base_suffix}")
            aliases+=("$base_suffix")
        fi

        for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
            docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
            docker push "${image_name}:${alias}"
            log "Pushed alias: ${alias}"
        done
    elif [ "$series" = "cli" ]; then
        # CLI 镜像的标签规则：cli-2.12.0-php8.2, cli-2.12-php8.2, cli-2-php8.2, cli-php8.2, cli-2.12.0, cli-2.12, cli-2, cli
        php_ver="${suffix#php}"
        aliases=()
        aliases+=("cli-${full_version}-${suffix}")
        aliases+=("cli-${major_minor}-${suffix}")
        aliases+=("cli-${major}-${suffix}")
        aliases+=("cli-${suffix}")
        aliases+=("cli-${full_version}")
        aliases+=("cli-${major_minor}")
        aliases+=("cli-${major}")
        aliases+=("cli")
        for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
            docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
            docker push "${image_name}:${alias}"
            log "Pushed alias: ${alias}"
        done
    fi
done

log "All variants for series $series done."
