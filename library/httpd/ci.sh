#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly ORG=''
readonly PROJ=''
main()
{
    # 1.获取要构建的版本
    readarray -t versions <<< $(./fetch_versions.sh)

    if [[ -z "$versions" ]]; then
        log INFO "No versions need updating"
        return 0
    else
        log INFO "Versions needing update: ${versions[@]}"
    fi

    # 2.执行构建
    for version in ${versions[@]}
    do
        log INFO "Process version $version"
        ./process_version.sh $version
    done

    ## 3.成功后更新 version.txt
    if [[ ! -z $versions ]]; then
        update_versions_file "versions.txt" "${versions[*]}"
    fi

    # 4. 提交仓库
    git_commit "$ORG" "$PROJ" "${versions[*]}"

    log INFO "All Versions:\n$(cat versions.txt)"
}

main "$@"
