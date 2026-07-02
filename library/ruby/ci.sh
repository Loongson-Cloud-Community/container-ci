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

    # 2. 读取 versions.json 获取完整版本号到主版本号的映射
    versions_json="template/versions.json"
    if [ ! -f "$versions_json" ]; then
        log ERROR "$versions_json not found"
        exit 1
    fi

    # 构建完整版本号到主版本号的映射
    declare -A full_to_major
    for major in $(jq -r 'keys[]' "$versions_json"); do
        full=$(jq -r ".[\"$major\"].version" "$versions_json")
        if [ -n "$full" ] && [ "$full" != "null" ]; then
            full_to_major["$full"]="$major"
        fi
    done

    # 3. 执行构建
    for full_version in ${full_versions[@]}
    do
        major_version="${full_to_major[$full_version]}"
        if [ -z "$major_version" ]; then
            log WARN "Cannot find major version for $full_version, skipping"
            continue
        fi
        log INFO "Process version $major_version ($full_version)"
        ./process_version.sh "$major_version"
        update_versions_file "processed_versions.txt" "$full_version"
    done

    git_commit "${full_versions[*]}"

    log INFO "All Versions:\n$(cat processed_versions.txt)"
}

main
