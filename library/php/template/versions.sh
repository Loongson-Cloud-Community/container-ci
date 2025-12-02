#!/bin/bash

version_json() {
    local php_version=$1
    local php_url="https://www.php.net/distributions/php-${php_version}.tar.xz"
    local php_asc_url="https://www.php.net/distributions/php-${php_version}.tar.xz.asc"
    local php_sha256=$(./sha256.sh "$php_version")
    jq -cnr \
        --arg php_version $php_version \
        --arg php_url $php_url \
        --arg php_asc_url $php_asc_url \
        --arg php_sha256 $php_sha256 \
    '{
        php_version: ($php_version),
        php_url: ($php_url),
        php_asc_url: ($php_asc_url),
        php_sha256: ($php_sha256),
    }'
}

res_dump(){
    local php_version=$1
    local version_info=$(version_json "${php_version}")
    jq -n \
        --arg php_version $php_version \
        --argjson version_info $version_info \
    '{
        ($php_version): ($version_info),
    }'  >versions.json
}


res_dump "$1"
