#!/bin/bash

set -eu

alpine_apply_single(){
    
    local nextcloud_version=$1
    local base_image_tag=$2
    local target_type=$3

    local build_dir="${nextcloud_version}/${target_type}-alpine" 


    mkdir -p "${build_dir}"
    jinja2 -D base_image_tag=${base_image_tag}  -D nextcloud_version=${nextcloud_version} "dockerfile-templates/Dockerfile-alpine-fpm.template" > "${build_dir}/Dockerfile"
    cp -r scripts-and-config/* "${build_dir}/"

    local tags="${nextcloud_version}-${target_type}-alpine"
    jinja2 -D tags=${tags} "Makefile.template" > "${build_dir}/Makefile"
    
}


debian_apply_single(){

    local nextcloud_version=$1
    local base_image_tag=$2
    local target_type=$3

    local build_dir="${nextcloud_version}/${target_type}" 


    mkdir -p "${build_dir}"
    jinja2 -D base_image_tag=${base_image_tag}  -D nextcloud_version=${nextcloud_version} "dockerfile-templates/Dockerfile-debian-fpm.template" > "${build_dir}/Dockerfile"
    cp -r scripts-and-config/* "${build_dir}/"

    local tags="${nextcloud_version}-${target_type}"
    jinja2 -D tags=${tags} "Makefile.template" > "${build_dir}/Makefile"

}

debian_apply() {

    local nextcloud_version=$1

    for target_type in apache fpm; do
        local base_image_tag="8.3.28-${target_type}-trixie"
        debian_apply_single "${nextcloud_version}" "${base_image_tag}" "${target_type}"
    done
    
}

alpine_apply() {

    local nextcloud_version=$1

    for target_type in fpm; do
        local base_image_tag="8.3.28-${target_type}-alpine3.22"
        alpine_apply_single "${nextcloud_version}" "${base_image_tag}" "${target_type}"
    done

}

main() {

    local nextcloud_version=$1
    
    debian_apply "${nextcloud_version}"
    alpine_apply "${nextcloud_version}"

}

main "$1"

