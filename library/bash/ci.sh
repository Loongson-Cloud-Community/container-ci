#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

git_commit() 
{
    versions=$(echo "$1" | tr '\n' ' ')
    git add versions.txt
    git add sources

    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    git commit -m "Add versions: $versions"
	git pull --rebase
    git push origin main
}

create_pr()
{
    # 1.创建临时工作目录
    local -r org='library'
    local -r pro='bash'
    local -r version=$1
    local -r wkdir=$(mktemp -d)
    local -r docker_library_url='https://github.com/Loongson-Cloud-Community/docker-library.git'
    local -r wkbranch="${org}-${pro}-${version}-$(echo $RANDOM)"

    # 2.下载代码，创建工作分支,生成项目
    pushd "${wkdir}"
    {
        git clone --depth=1 "${docker_library_url}"
        cd docker-library 
        git checkout -b "${wkbranch}"
        rm -rf "${org}/${pro}/${version}"
        ./generate.sh "${org}" "${pro}" "${version}"
        
    }
    popd

    # 3.拷贝 dockerfile
    local -r dstdir="${wkdir}/docker-library/${org}/${pro}/${version}"
    cp sources/${version}/* "${dstdir}/"

    # 4.修改完成发起pr
    pushd "${wkdir}/docker-library"
    {
    	git config user.name "github-actions[bot]"
    	git config user.email "github-actions[bot]@users.noreply.github.com"
        git add "${org}/${pro}/${version}"
        git commit -m "[auto submmit]: add ${org}/${pro}:${version}"
        git push origin "${wkbranch}"
        gh pr create \
            --title "update: add ${org}/${pro}:${version}" \
            --body "" \
            --head ${wkbranch} \
            --base main
    }
    popd
}

main()
{
    # 1.获取要构建的版本
    IFS=$'\n' versions=($(./fetch_versions.sh))

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
        ./process_version.sh ${version}
    done

    # 3.发起pr
    for version in ${versions[@]}
    do
        log INFO "Create pr version=${version}"
		create_pr "${version}"
    done

    # 4.成功后更新 version.txt 并提交仓库
    if [[ ! -z $versions ]]; then
        update_versions_file "versions.txt" "${versions[*]}"
    fi
    
    git_commit "${versions[*]}"

    log INFO "All Versions:\n$(cat versions.txt)"
}

main "$@"
