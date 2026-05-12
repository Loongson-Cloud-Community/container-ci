#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly ORG='library'
readonly PROJ='php'

git_commit()
{
    versions=$(echo "$1" | tr '\n' ' ')
    git add .
    git config user.name "huangyang"
    git config user.email "huangyang@loongson.cn"
    git commit -m "$ORG $PROJ: Add versions: $versions"
    git pull --rebase
    git push origin main
}

main()
{
    # 0. 更新版本信息和生成 Dockerfile
    log INFO "Updating PHP versions and generating Dockerfiles from upstream..."
    if [ ! -x template/update.sh ]; then
        log ERROR "template/update.sh not found or not executable"
        exit 1
    fi
    pushd template >/dev/null
    ./update.sh
    popd >/dev/null

    # 1. 获取需要构建的版本（仅未处理过的版本）
    IFS=$'\n' versions=($(./fetch_versions.sh))

    if [[ -z "$versions" ]]; then
        log INFO "No versions need updating"
        return 0
    else
        log INFO "Versions needing update: ${versions[@]}"
    fi

    # 2. 执行构建
    for version in ${versions[@]}
    do
        log INFO "Process version $version"
        ./process_version.sh ${version}
        update_versions_file "processed_versions.txt" "${version}"
    done

    git_commit "${versions[*]}"

    log INFO "All Versions:\n$(cat processed_versions.txt)"
}

main
