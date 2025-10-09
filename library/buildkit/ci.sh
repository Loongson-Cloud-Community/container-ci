#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly ORG='library'
readonly PROJ='buildkit'
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
    # 确定buildx 存在
    log INFO "Prepare buildx"
    # 检查buildx是否存在
    if [ ! -x ~/.docker/cli-plugins/docker-buildx ];then
        echo "Docker Buildx未安装，开始下载安装..."

        # 创建临时目录

        #  下载文件（添加错误处理）
        if ! wget -q https://cloud.loongnix.cn/releases/loongarch64/docker/buildx/0.12.0-rc1/buildx-linux-loong64.tar.gz; then
            echo "下载失败，请检查网络或链接有效性"
            exit 1
        fi

        # 解压并安装
        tar -xzf buildx-linux-loong64.tar.gz
        mkdir -p ~/.docker/cli-plugins
        mv $(pwd)/bin/build/docker-buildx ~/.docker/cli-plugins/docker-buildx
        chmod +x ~/.docker/cli-plugins/docker-buildx

        echo "Buildx安装完成！"
    else
        echo "Docker Buildx已安装，版本：$(docker buildx version)"
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
