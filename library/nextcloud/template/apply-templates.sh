#!/bin/bash

set -eux

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

debian_apply_single '31.0.11' '8.3.28-fpm-trixie' 'apache'
