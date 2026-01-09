#!/bin/bash

alpine_apply_single() {

	local node_version=$1
	local alpine_version=$2

	# 生成 dockerfile
	local build_dir="${node_version}/alpine${alpine_version}"
	mkdir -p "${build_dir}"
    jq <versions.json -rc --arg node_version $node_version '.[$node_version]' | \
        jinja2 -D alpine_version=${alpine_version} -D node_version=${node_version} "templates/Dockerfile-alpine.template" - \
        >"${build_dir}/Dockerfile"

	# 拷贝脚本
	cp docker-scripts/docker-* "${build_dir}/"

	# 生成 makefile
	local major=$(echo "${node_version}" | cut -d. -f1)
	local short_version=$(echo "${node_version}" | cut -d. -f1,2)
	local tags="${node_version}-alpine${alpine_version},${short_version}-alpine${alpine_version},${major}-alpine${alpine_version}"
	jinja2 "templates/Makefile.template" -D tags=$tags >"${build_dir}/Makefile"
}

debian_apply_single() {

    local node_version=$1
    local debian_version=$2
    
    # 生成 dockerfile
    local build_dir="${node_version}/$debian_version"
    mkdir -p "${build_dir}"
    jq <versions.json -rc --arg node_version $node_version '.[$node_version]' | \
        jinja2 -D debian_version=${debian_version} -D node_version=${node_version} "templates/Dockerfile-debian.template" - \
        >"${build_dir}/Dockerfile"

    # 拷贝脚本
    cp docker-scripts/docker-* "${build_dir}/"

    # 生成 makefile
    local major=$(echo "${node_version}" | cut -d. -f1)
    local short_version=$(echo "${node_version}" | cut -d. -f1,2)
    local tags="${node_version}-${debian_version},${short_version}-${debian_version},${major}-${debian_version},${node_version},${short_version},${major}"
    jinja2 "templates/Makefile.template" -D tags=$tags >"${build_dir}/Makefile"
}

debian_slim_apply_single() {

    local node_version=$1
    local debian_version=$2

    # 生成 dockerfile
    local build_dir="${node_version}/${debian_version}-slim"
    mkdir -p "${build_dir}"
    jq <versions.json -rc --arg node_version $node_version '.[$node_version]' | \
        jinja2 -D debian_version=${debian_version} -D node_version=${node_version} "templates/Dockerfile-debian-slim.template" - \
        >"${build_dir}/Dockerfile"

    # 拷贝脚本
    cp docker-scripts/docker-* "${build_dir}/"

    # 生成 makefile
    local major=$(echo "${node_version}" | cut -d. -f1)
    local short_version=$(echo "${node_version}" | cut -d. -f1,2)
    local tags="${node_version}-${debian_version}-slim,${short_version}-${debian_version}-slim,${major}-${debian_version}-slim"
    jinja2 "templates/Makefile.template" -D tags=$tags >"${build_dir}/Makefile"
}

alpine_apply() {
    local node_version=$1

    for alpine_version in 3.21 3.22 3.23; do
        alpine_apply_single ${node_version} ${alpine_version}
    done
}

debian_apply() {
    local node_version=$1

    for debian_version in trixie; do
        debian_apply_single ${node_version} ${debian_version}
    done
}

debian_slim_apply() {
    local node_version=$1

    for debian_version in trixie; do
        debian_slim_apply_single ${node_version} ${debian_version}
    done
}

main() {
    local node_version=$1

    alpine_apply ${node_version}
    debian_apply ${node_version}
    debian_slim_apply ${node_version}
}

main "$1"
