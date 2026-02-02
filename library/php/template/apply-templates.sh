#!/bin/bash

set -e

alpine_apply_single(){

    local php_version=$1
    local alpine_version=$2
    local target_type=$3
    local php_info=$(jq -cr --arg php_vesion $php_version '.[$php_vesion]' versions.json)

    # 生成 Dockerfile
    local build_dir="${php_version}/alpine${alpine_version}/${target_type}"
    mkdir -p "${build_dir}"
    echo "${php_info}" | jinja2 -D alpine_version=${alpine_version} "templates/Dockerfile-alpine-${target_type}.template" - > "${build_dir}/Dockerfile"

    # 拷贝脚本
    cp docker-scripts/docker-php-* "${build_dir}/"

    # 生成 makefile
    local tags="${php_version}-${target_type}-alpine${alpine_version}"
    jinja2 Makefile.template -D tags=$tags >"${build_dir}/Makefile"

}

debian_apply_single(){

    local php_version=$1
    local debian_version=$2
    local target_type=$3
    local php_info=$(jq -cr --arg php_vesion $php_version '.[$php_vesion]' versions.json)

    # 生成Dockerfile
    local build_dir="${php_version}/${debian_version}/${target_type}"
    mkdir -p "${build_dir}"
    echo "${php_info}" | jinja2 -D debian_version=${debian_version} "templates/Dockerfile-debian-${target_type}.template" - > "${build_dir}/Dockerfile"


    # 拷贝脚本
    if test 'apache' = "$target_type"; then
        cp docker-scripts/* "${build_dir}/"
    else
        cp docker-scripts/docker-php-* "${build_dir}/"
    fi

    # 生成 makefile
    local tags="${php_version}-${target_type}-${debian_version}"
    jinja2 Makefile.template -D tags=$tags >"${build_dir}/Makefile"

}

alpine_apply() {
    local php_version=$1
    for alpine_version in 3.21 3.22 3.23; do
        for target_type in cli fpm zts; do
            alpine_apply_single "${php_version}" "${alpine_version}" "${target_type}"
        done
    done

}

debian_apply() {
    local php_version=$1
    for debian_version in unstable; do
        for target_type in cli fpm zts apache; do
            debian_apply_single "${php_version}" "${debian_version}" "${target_type}"
        done
    done
}

main() {
    local php_version="$1"
    alpine_apply "$php_version"
    debian_apply "$php_version"
}

main "$1"
