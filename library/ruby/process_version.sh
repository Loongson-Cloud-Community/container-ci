#!/bin/bash
set -eo pipefail

source "$(dirname $0)/lib.sh"

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="ruby"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <full_version> (e.g. 4.0.5)"
    exit 1
fi

full_version="$1"
versions_json="template/versions.json"

# 从完整版本号提取主版本号（如 4.0.5 -> 4.0）
major_version="${full_version%.*}"

log INFO "Processing Ruby $major_version ($full_version)"

# 1. 生成 versions.json（如果不存在或需要更新）
cd template
if [ ! -f "versions.json" ] || ! jq -e ".[\"$major_version\"] | .version == \"$full_version\"" versions.json > /dev/null 2>&1; then
    log INFO "Generating versions.json for version $major_version..."
    ./versions.sh "$major_version"
fi

# 2. 调用 apply-templates.sh 生成 Dockerfile
log INFO "Generating Dockerfiles for version $major_version..."
./apply-templates.sh "$major_version"
cd ..

# 3. 查找完整版本号对应的配置
found_version=$(jq -r ".[\"$major_version\"].version // empty" "$versions_json")
if [ "$found_version" != "$full_version" ]; then
    log ERROR "Version $full_version not found in $versions_json (expected $found_version)"
    exit 1
fi

log INFO "Building Ruby $major_version ($full_version)"

# 4. 获取该版本的所有变体（例如 forky, slim-forky, alpine3.24）
variants=$(jq -r ".[\"$major_version\"].variants[]" "$versions_json")

for variant in $variants; do
    build_dir="template/$major_version/$variant"
    if [ ! -d "$build_dir" ]; then
        log WARN "Directory $build_dir not found, skipping"
        continue
    fi

    # 检查 Dockerfile 是否存在
    if [ ! -f "$build_dir/Dockerfile" ]; then
        log WARN "Dockerfile not found in $build_dir, skipping"
        continue
    fi

    image_name="${REGISTRY}/${ORG}/${PROJ}"
    specific_tag="${full_version}-${variant}"

    log INFO "Building $image_name:$specific_tag"
    docker build --network host -t "${image_name}:${specific_tag}" "$build_dir" || {
        log ERROR "Build failed for variant $variant"
        exit 1
    }

    log INFO "Pushing $image_name:$specific_tag"
    docker push "${image_name}:${specific_tag}" || {
        log ERROR "Push failed for variant $variant"
        exit 1
    }

    # 生成别名列表（根据官方 Ruby 标签规则）
    aliases=()

    # 判断变体类型
    if [[ "$variant" == "alpine"* ]]; then
        # Alpine 变体，例如 alpine3.24
        alpine_ver=$(echo "$variant" | sed 's/alpine//')   # 3.24
        aliases+=("${full_version}-${variant}")
        aliases+=("${major_version}-${variant}")
        aliases+=("${major_version%%.*}-${variant}")
        # 如果是最新 Alpine 版本（3.24），添加无具体版本号的 alpine 别名
        if [ "$alpine_ver" = "3.24" ]; then
            aliases+=("${full_version}-alpine")
            aliases+=("${major_version}-alpine")
            aliases+=("${major_version%%.*}-alpine")
            aliases+=("alpine")
        fi
    else
        # Debian 变体：forky 或 slim-forky
        if [[ "$variant" == "slim-forky" ]]; then
            # slim 变体
            aliases+=("${full_version}-${variant}")
            aliases+=("${major_version}-${variant}")
            aliases+=("${major_version%%.*}-${variant}")
            # 通用 slim 别名
            aliases+=("${full_version}-slim")
            aliases+=("${major_version}-slim")
            aliases+=("${major_version%%.*}-slim")
            aliases+=("slim")
        elif [[ "$variant" == "forky" ]]; then
            # 标准 Debian 变体（默认）
            aliases+=("${full_version}-${variant}")
            aliases+=("${major_version}-${variant}")
            aliases+=("${major_version%%.*}-${variant}")
            # 顶级版本别名（无后缀）
            aliases+=("${full_version}")
            aliases+=("${major_version}")
            aliases+=("${major_version%%.*}")
        else
            # 其他未知变体，只保留自身标签
            aliases+=("${full_version}-${variant}")
        fi
    fi

    # 去重并推送
    for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
        docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
        docker push "${image_name}:${alias}"
        log INFO "Pushed alias: ${alias}"
    done
done

log INFO "All variants for version $major_version done."
