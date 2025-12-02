#!/bin/bash

alpine_apply() {
    local php_version=$1
    local alpine_version='3.21'
    local php_info=$(jq -cr --arg php_vesion $php_version '.[$php_vesion]' versions.json)
    # 3.21
    echo "${php_info}" | jinja2 -D alpine_version=3.21 Dockerfile-alpine-cli.template - > "${php_version}/alpine${alpine_version}/cli/Dockerfile"
    echo "${php_info}" | jinja2 -D alpine_version=3.21 Dockerfile-alpine-fpm.template - > "${php_version}/alpine${alpine_version}/fpm/Dockerfile"
    echo "${php_info}" | jinja2 -D alpine_version=3.21 Dockerfile-alpine-zts.template - > "${php_version}/alpine${alpine_version}/zts/Dockerfile"
    # 3.22
    alpine_version='3.22'
    echo "${php_info}" | jinja2 -D alpine_version=3.22 Dockerfile-alpine-cli.template - > "${php_version}/alpine${alpine_version}/cli/Dockerfile"
    echo "${php_info}" | jinja2 -D alpine_version=3.22 Dockerfile-alpine-fpm.template - > "${php_version}/alpine${alpine_version}/fpm/Dockerfile"
    echo "${php_info}" | jinja2 -D alpine_version=3.22 Dockerfile-alpine-zts.template - > "${php_version}/alpine${alpine_version}/zts/Dockerfile"
}


debian_apply() {
    local php_version=$1
    local debian_version=trixie
    local php_info=$(jq -cr --arg php_vesion $php_version '.[$php_vesion]' versions.json)
    echo "${php_info}" | jinja2 -D debian_version=trixie templates/Dockerfile-debian-cli.template - > "${php_version}/${debian_version}/cli/Dockerfile"
    echo "${php_info}" | jinja2 -D debian_version=trixie templates/Dockerfile-debian-fpm.template - > "${php_version}/${debian_version}/fpm/Dockerfile"
    echo "${php_info}" | jinja2 -D debian_version=trixie templates/Dockerfile-debian-zts.template - > "${php_version}/${debian_version}/zts/Dockerfile"

}

debian_apply '8.3.27'
