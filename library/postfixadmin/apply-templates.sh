#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

if [ ! -f template/versions.json ]; then
    echo "ERROR: template/versions.json not found. Run fetch_versions.sh first."
    exit 1
fi

version=$(jq -r 'keys[0]' template/versions.json)
sha512=$(jq -r ".[\"$version\"].sha512" template/versions.json)

declare -A variants=(
    [apache]="lcr.loongnix.cn/library/php:8.3-apache-forky"
    [fpm]="lcr.loongnix.cn/library/php:8.3-fpm-forky"
    [fpm-alpine]="lcr.loongnix.cn/library/php:8.3-fpm-alpine3.23"
)

find template -mindepth 1 -maxdepth 1 -type d ! -name '.' -exec rm -rf {} + 2>/dev/null || true

for variant in "${!variants[@]}"; do
    base_image="${variants[$variant]}"
    if [ -z "$base_image" ]; then
        echo "ERROR: Unknown variant $variant" >&2
        continue
    fi

    case "$variant" in
        apache|fpm) template_file="template/Dockerfile-debian.template" ;;
        fpm-alpine) template_file="template/Dockerfile-alpine.template" ;;
    esac

    target_dir="template/$version/$variant"
    mkdir -p "$target_dir"

    echo "Generating $target_dir/Dockerfile from $template_file"

    sed -e "s|^FROM .*$|FROM $base_image|g" \
        -e "s|^ARG POSTFIXADMIN_VERSION=.*$|ARG POSTFIXADMIN_VERSION=$version|g" \
        -e "s|^ARG POSTFIXADMIN_SHA512=.*$|ARG POSTFIXADMIN_SHA512=$sha512|g" \
        "$template_file" > "$target_dir/Dockerfile"

    # 替换 composer 镜像源
    sed -i 's|COPY --from=composer:2 /usr/bin/composer /usr/local/bin/|COPY --from=lcr.loongnix.cn/library/composer:v2.9.5 /usr/bin/composer /usr/local/bin/|' "$target_dir/Dockerfile"

    # 对于非 apache 变体，删除 Apache 相关配置
    if [ "$variant" != "apache" ]; then
        sed -i '/APACHE_DOCUMENT_ROOT/d' "$target_dir/Dockerfile"
        sed -i '/sed.*APACHE_DOCUMENT_ROOT/d' "$target_dir/Dockerfile"
    fi

    cp template/docker-entrypoint.sh "$target_dir/"
done

echo "All Dockerfiles generated in template/$version/"
