#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly ORG='library'
readonly PROJ='ruby'

git_commit() 
{
    versions=$(echo "$1" | tr '\n' ' ')
    git add .

    git config user.name "CI Bot"
    git config user.email "ci@loongson.cn"
    git commit -m "$ORG $PROJ: Add versions: $versions"
    git pull --rebase
    git push origin main
}


main()
{
    # 1. 获取要构建的版本（完整版本号，如 3.3.11, 3.4.3, 4.0.5）
    IFS=$'\n' full_versions=($(./fetch_versions.sh))

    if [[ -z "$full_versions" ]]; then
        log INFO "No versions need updating"
        return 0
    else
        log INFO "Versions needing update: ${full_versions[@]}"
    fi

    # 2. 执行构建（process_version.sh 内部处理 full->major 映射）
    for full_version in ${full_versions[@]}
    do
        log INFO "Process version $full_version"
        ./process_version.sh "$full_version"
        update_versions_file "processed_versions.txt" "$full_version"
    done

    git_commit "${full_versions[*]}"

    log INFO "All Versions:\n$(cat processed_versions.txt)"
}

main
