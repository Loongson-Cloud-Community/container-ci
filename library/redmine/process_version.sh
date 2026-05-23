#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="redmine"

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
            # 使用 forky 作为默认变体，标签后缀为 forky
            actual_suffix="forky"
            build_variant="$variant"
            ;;
        alpine3.23)
            actual_suffix="$variant"
            build_variant="$variant"
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

    # 修改 Dockerfile 中的基础镜像
    dockerfile="$build_dir/Dockerfile"
    ruby_version=$(jq -r ".[\"$version\"].ruby.version" "$versions_json")
    if [[ "$actual_suffix" == "alpine"* ]]; then
        new_base="lcr.loongnix.cn/library/ruby:${ruby_version}-${actual_suffix}"
    else
        # 非 alpine 变体（即 forky）使用 -forky 基础镜像
        new_base="lcr.loongnix.cn/library/ruby:${ruby_version}-forky"
    fi
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

    # 生成别名
    major_minor=$(echo "$full_version" | cut -d. -f1,2)
    major=$(echo "$full_version" | cut -d. -f1)
    aliases=()

    if [[ "$actual_suffix" == "alpine"* ]]; then
        # alpine 变体的别名
        aliases+=("${full_version}-${actual_suffix}")
        aliases+=("${major_minor}-${actual_suffix}")
        aliases+=("${major}-${actual_suffix}")
        aliases+=("${actual_suffix}")
        if [ "$actual_suffix" = "alpine3.23" ]; then
            aliases+=("${full_version}-alpine")
            aliases+=("${major_minor}-alpine")
            aliases+=("${major}-alpine")
            aliases+=("alpine")
        fi
    else
        # forky 变体：作为默认变体，拥有无后缀标签和 latest
        aliases+=("${full_version}-forky")
        aliases+=("${major_minor}-forky")
        aliases+=("${major}-forky")
        aliases+=("forky")
        # 顶级版本标签（无后缀）
        aliases+=("$full_version")
        aliases+=("$major_minor")
        aliases+=("$major")
        # 如果是最新大版本（例如 6.1），添加 latest
        if [ "$version" = "6.1" ]; then
            aliases+=("latest")
        fi
    fi

    for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
        docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
        docker push "${image_name}:${alias}"
        log "Pushed alias: ${alias}"
    done
done

log "All variants for version $version done."
