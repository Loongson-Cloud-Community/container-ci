#!/bin/bash
set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly ORG='library'
readonly PROJ='phpmyadmin'

git_commit() {
    local versions="$1"
    git add .
    git config user.name "huangyang"
    git config user.email "huangyang@loongson.cn"
    git commit -m "$ORG $PROJ: Add version: $versions"
    git pull --rebase
    git push origin main
}

main() {
    # 获取要构建的版本
    versions=($(./fetch_versions.sh))
    if [[ -z "$versions" ]]; then
        log INFO "No versions need updating"
        return 0
    fi

    log INFO "Version to build: ${versions[0]}"
    ./process_version.sh "${versions[0]}"

    # 记录已处理版本
    update_versions_file "processed_versions.txt" "${versions[0]}"
    git_commit "${versions[0]}"
}

main
