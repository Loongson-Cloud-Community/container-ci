#!/bin/bash

set -e

get_php_info_on_cloud() {
    local php_version=$1
    local php_url="https://cloud.loongnix.cn/releases/loongarch64/php/php-src/${php_version}/php-${php_version}.tar.xz"
    local php_sha256=`wget -O- https://cloud.loongnix.cn/releases/loongarch64/php/php-src/${php_version}/php-${php_version}.sha256sum`
    jq -cnr \
        --arg php_version $php_version \
        --arg php_url $php_url \
        --arg php_sha256 $php_sha256 \
    '{
        php_version: ($php_version),
        php_url: ($php_url),
        php_sha256: ($php_sha256),
    }'
}

get_php_info_on_phpnet() {
    local php_version=$1
    local php_url="https://www.php.net/distributions/php-${php_version}.tar.xz"
    local php_sha256=$(./sha256.sh "$php_version")
    jq -cnr \
        --arg php_version $php_version \
        --arg php_url $php_url \
        --arg php_sha256 $php_sha256 \
    '{
        php_version: ($php_version),
        php_url: ($php_url),
        php_sha256: ($php_sha256),
    }'
}

get_php_info() {
    local php_version=$1
    local php_info='{}'
    if curl -f -s -o /dev/null https://cloud.loongnix.cn/releases/loongarch64/php/php-src/${php_version}/php-${php_version}.sha256sum; then
        php_info=`get_php_info_on_cloud ${php_version}`
    else
        php_info=`get_php_info_on_phpnet ${php_version}`
    fi
    jq -cnr --arg php_version "${php_version}" --argjson php_info "${php_info}" \
    '{
        ($php_version): ($php_info)
    }' 
}

append_php_info() {
    local php_version="$1"
    local php_info=`get_php_info ${php_version}`
    local origin_data=`cat versions.json | jq -cr --arg php_version "${php_version}" 'del(.[$php_version])'`
    jq -n \
        --argjson php_info ${php_info} \
        --argjson origin_data ${origin_data} \
        '($php_info) + ($origin_data)' > versions.json
}

main() {
    append_php_info "$1"
}

main "$1"



