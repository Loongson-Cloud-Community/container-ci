#!/bin/bash
set -eo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="ruby"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <major_version> (e.g. 3.3)"
    exit 1
fi

version="$1"
versions_json="template/versions.json"

full_version=$(jq -r ".[\"$version\"].version" "$versions_json")
if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
    log "ERROR: Cannot find full version for $version in $versions_json"
    exit 1
fi
log "Building Ruby $version ($full_version)"

# 获取该版本的所有变体（例如 forky, slim-forky, alpine3.23, alpine3.22）
variants=$(jq -r ".[\"$version\"].variants[]" "$versions_json")

for variant in $variants; do
    build_dir="template/$version/$variant"
    if [ ! -d "$build_dir" ]; then
        log "WARNING: Directory $build_dir not found, skipping"
        continue
    fi

    image_name="${REGISTRY}/${ORG}/${PROJ}"
    specific_tag="${full_version}-${variant}"

    log "Building $image_name:$specific_tag"
    docker build --network host -t "${image_name}:${specific_tag}" "$build_dir" || {
        log "ERROR: Build failed for variant $variant"
        exit 1
    }

    log "Pushing $image_name:$specific_tag"
    docker push "${image_name}:${specific_tag}" || {
        log "ERROR: Push failed for variant $variant"
        exit 1
    }

    # 生成别名列表（根据官方 Ruby 标签规则）
    aliases=()

    # 判断变体类型
    if [[ "$variant" == "alpine"* ]]; then
        # Alpine 变体，例如 alpine3.23, alpine3.22
        alpine_ver=$(echo "$variant" | sed 's/alpine//')   # 3.23 或 3.22
        aliases+=("${full_version}-${variant}")
        aliases+=("${version}-${variant}")
        aliases+=("${version%%.*}-${variant}")
        # 如果是最新 Alpine 版本（3.23），添加无具体版本号的 alpine 别名
        if [ "$alpine_ver" = "3.23" ]; then
            aliases+=("${full_version}-alpine")
            aliases+=("${version}-alpine")
            aliases+=("${version%%.*}-alpine")
            aliases+=("alpine")
        fi
    else
        # Debian 变体：forky 或 slim-forky
        if [[ "$variant" == "slim-forky" ]]; then
            # slim 变体
            aliases+=("${full_version}-${variant}")
            aliases+=("${version}-${variant}")
            aliases+=("${version%%.*}-${variant}")
            # 通用 slim 别名
            aliases+=("${full_version}-slim")
            aliases+=("${version}-slim")
            aliases+=("${version%%.*}-slim")
            aliases+=("slim")
        elif [[ "$variant" == "forky" ]]; then
            # 标准 Debian 变体（默认）
            aliases+=("${full_version}-${variant}")
            aliases+=("${version}-${variant}")
            aliases+=("${version%%.*}-${variant}")
            # 顶级版本别名（无后缀）
            aliases+=("${full_version}")
            aliases+=("${version}")
            aliases+=("${version%%.*}")
            # 注意：latest 标签根据官方规则，由最新的大版本（如 4.0）推送，此处略，可在 ci.sh 中额外处理
        else
            # 其他未知变体，只保留自身标签
            aliases+=("${full_version}-${variant}")
        fi
    fi

    # 去重并推送
    for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
        docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
        docker push "${image_name}:${alias}"
        log "Pushed alias: ${alias}"
    done
done

log "All variants for version $version done."
