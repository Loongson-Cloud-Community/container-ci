#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='phpmyadmin'

# 变体列表
VARIANTS=("apache" "fpm" "fpm-alpine")

# 官方 GPG 密钥
GPG_KEY='3D06A59ECE730EB71B511C17CE752F178259BD92'

# 固定 PHP 版本（官方使用 8.3）
PHP_VERSION='8.3'

get_version_info() {
    local ver="$1"
    local url="https://files.phpmyadmin.net/phpMyAdmin/${ver}/phpMyAdmin-${ver}-all-languages.tar.xz"
    local sha256="$(curl -fsSL "${url}.sha256" | cut -f1 -d ' ' | tr -cd 'a-f0-9' | cut -c 1-64)"
    echo "$url" "$sha256"
}

prepare_variant() {
    local version="$1"
    local variant="$2"
    local base="$3"   # debian 或 alpine
    local target_dir="./template/$version/$variant"
    mkdir -p "$target_dir"

    local template_file="templates/Dockerfile-${base}.template"
    if [[ ! -f "$template_file" ]]; then
        log ERROR "Template $template_file not found"
        exit 1
    fi

    local cmd
    if [[ "$variant" == "apache" ]]; then
        cmd="apache2-foreground"
    else
        cmd="php-fpm"
    fi

    sed -e "s/%%VARIANT%%/$variant/g" \
        -e "s/%%VERSION%%/$version/g" \
        -e "s/%%SHA256%%/$sha256/g" \
        -e "s|%%DOWNLOAD_URL%%|$url|g" \
        -e "s|%%DOWNLOAD_URL_ASC%%|${url}.asc|g" \
        -e "s/%%PHP_VERSION%%/$PHP_VERSION/g" \
        -e "s/%%GPG_KEY%%/$GPG_KEY/g" \
        -e "s/%%CMD%%/$cmd/g" \
        "$template_file" > "$target_dir/Dockerfile"

    # 复制公共文件
    cp templates/docker-entrypoint.sh "$target_dir/"
    cp templates/config.inc.php "$target_dir/"
    cp templates/helpers.php "$target_dir/"

    # 对于非 apache 变体，移除 apache 专用部分
    if [[ "$variant" != "apache" ]]; then
        sed -i "/^# start: Apache specific settings$/,/^# end: Apache specific settings$/d" "$target_dir/docker-entrypoint.sh"
        sed -i "/^\s*# start: Apache specific build$/,/^\s*# end: Apache specific build$/d" "$target_dir/Dockerfile"
    fi
}

build_and_push_variant() {
    local version="$1"
    local variant="$2"
    local build_dir="./template/$version/$variant"
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local specific_tag="${version}-${variant}"

    log INFO "Building ${image_name}:${specific_tag} from $build_dir"
    docker build --no-cache -t "${image_name}:${specific_tag}" "$build_dir" || {
        log ERROR "Build failed for ${image_name}:${specific_tag}"
        exit 1
    }

    docker push "${image_name}:${specific_tag}" || exit 1
    log INFO "Pushed ${image_name}:${specific_tag}"

    local major_minor="${version%.*}"
    local major="${major_minor%.*}"
    local aliases=()

    # 变体短别名
    aliases+=("${major_minor}-${variant}")
    aliases+=("${major}-${variant}")
    aliases+=("$variant")

    if [[ "$variant" == "apache" ]]; then
        aliases+=("$version")
        aliases+=("$major_minor")
        aliases+=("$major")
        # 只有最新版本才推送 `latest`（由外部 LATEST_VERSION 环境变量控制）
        if [[ "$version" == "$LATEST_VERSION" ]]; then
            aliases+=("latest")
        fi
    fi

    for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
        docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
        docker push "${image_name}:${alias}"
        log INFO "Pushed alias: ${alias}"
    done
}

main() {
    local version="$1"
    if [[ -z "$version" ]]; then
        log ERROR "No version specified"
        exit 1
    fi
    export LATEST_VERSION="$version"

    read url sha256 <<< $(get_version_info "$version")
    if [[ -z "$sha256" ]]; then
        log ERROR "Failed to get info for version $version"
        exit 1
    fi

    for variant in "${VARIANTS[@]}"; do
        case "$variant" in
            apache|fpm)        base="debian" ;;
            fpm-alpine)        base="alpine" ;;
        esac
        prepare_variant "$version" "$variant" "$base"
    done

    for variant in "${VARIANTS[@]}"; do
        build_and_push_variant "$version" "$variant"
    done
}

main "$1"
