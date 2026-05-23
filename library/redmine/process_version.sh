#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="redmine"

# 当前最新大版本，决定无后缀标签和 latest 的归属
LATEST_MAJOR="6.1"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <major_version>"
    exit 1
fi

version="$1"
versions_json="template/versions.json"

full_version=$(jq -r ".[\"$version\"].version" "$versions_json")
if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
    log "ERROR: Cannot find full version for $version"
    exit 1
fi
log "Building Redmine $version ($full_version)"

variants=$(jq -r ".[\"$version\"].variants[]" "$versions_json")

for variant in $variants; do
    case "$variant" in
        forky)
            actual_suffix="forky"
            build_variant="$variant"
            ;;
        alpine*)
            # Alpine loong64 仓库缺失 lcms2 子库，暂时跳过
            log "Skipping $variant (Alpine loong64 dependencies incomplete)"
            continue
            ;;
        *)
            log "Skipping unknown variant $variant"
            continue
            ;;
    esac

    build_dir="template/$version/$build_variant"
    if [ ! -d "$build_dir" ]; then
        log "WARNING: Directory $build_dir not found, skipping"
        continue
    fi

    # 修改基础镜像为 forky 版
    dockerfile="$build_dir/Dockerfile"
    ruby_version=$(jq -r ".[\"$version\"].ruby.version" "$versions_json")
    new_base="lcr.loongnix.cn/library/ruby:${ruby_version}-forky"
    sed -i "s|^FROM .*$|FROM $new_base|g" "$dockerfile"

    image_name="${REGISTRY}/${ORG}/${PROJ}"
    specific_tag="${full_version}-${actual_suffix}"

    log "Building $image_name:$specific_tag from $build_dir"
    docker build --network host -t "${image_name}:${specific_tag}" "$build_dir" || {
        log "ERROR: Build failed for variant $variant"
        exit 1
    }

    log "Pushing $image_name:$specific_tag"
    docker push "${image_name}:${specific_tag}" || {
        log "ERROR: Push failed for variant $variant"
        exit 1
    }

    # 生成别名标签
    major_minor=$(echo "$full_version" | cut -d. -f1,2)
    major=$(echo "$full_version" | cut -d. -f1)
    aliases=()

    # forky 变体始终携带 -forky 后缀
    aliases+=("${full_version}-forky")
    aliases+=("${major_minor}-forky")
    aliases+=("${major}-forky")
    aliases+=("forky")

    # 只有最新大版本才推送无后缀的顶级标签和 latest
    if [ "$version" = "$LATEST_MAJOR" ]; then
        aliases+=("$full_version")
        aliases+=("$major_minor")
        aliases+=("$major")
        aliases+=("latest")
    fi

    for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
        docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
        docker push "${image_name}:${alias}"
        log "Pushed alias: ${alias}"
    done
done

log "All variants for version $version done."
