#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='php'

# ---- 辅助函数 ----
get_full_version() {
    local major_minor="$1"
    jq -r ".[\"$major_minor\"].version" ./template/versions.json
}

get_all_major_versions() {
    jq -r 'keys[] | select(contains("-rc") | not)' ./template/versions.json | sort -V
}

get_latest_major() {
    get_all_major_versions | tail -n1
}

get_alpine_variants() {
    local major_minor="$1"
    find "./template/$major_minor" -maxdepth 1 -type d -name 'alpine*' -exec basename {} \; | sort -V
}

is_latest_alpine() {
    local major_minor="$1"
    local alpine_ver="$2"
    local latest=$(get_alpine_variants "$major_minor" | tail -n1)
    [[ "$alpine_ver" == "$latest" ]]
}

# 构建并推送单个变体
build_and_push_variant() {
    local major_minor="$1"
    local full_version="$2"
    local build_dir="$3"
    local relative_path="${build_dir#./template/$major_minor/}"
    local target_type=$(basename "$relative_path")        # cli, apache, fpm, zts
    local os_variant=$(dirname "$relative_path")          # forky, alpine3.22, alpine3.23

    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local specific_tag="${full_version}-${target_type}-${os_variant}"

    log INFO "Building ${image_name}:${specific_tag} from $build_dir"
    docker build -t "${image_name}:${specific_tag}" "$build_dir" || {
        log ERROR "Build failed for ${image_name}:${specific_tag}"
        exit 1
    }

    docker push "${image_name}:${specific_tag}" || exit 1
    log INFO "Pushed ${image_name}:${specific_tag}"

    local aliases=()
    # 短版本 + 完整变体
    aliases+=("${major_minor}-${target_type}-${os_variant}")

    # ---- Debian (forky) 变体 ----
    if [[ "$os_variant" == "forky" ]]; then
        # 默认标签（不带 -forky）
        aliases+=("${full_version}-${target_type}")
        aliases+=("${major_minor}-${target_type}")

        if [[ "$target_type" == "cli" ]]; then
            # 顶级版本号
            aliases+=("${full_version}")                # 8.4.21
            aliases+=("${major_minor}")                 # 8.4
            # 带基础镜像名的无变体标签（对应官方 trixie）
            aliases+=("${full_version}-${os_variant}")  # 8.4.21-forky
            aliases+=("${major_minor}-${os_variant}")   # 8.4-forky

            # 只有最新大版本才推 major (8) 和 latest
            local latest_major=$(get_latest_major)
            if [[ "$major_minor" == "$latest_major" ]]; then
                local major_num="${major_minor%%.*}"
                aliases+=("$major_num")                 # 8
                aliases+=("latest")                     # latest
            fi
        fi
    fi

    # ---- Alpine 变体 ----
    if [[ "$os_variant" =~ ^alpine ]]; then
        # 短版本 + 完整变体（已添加，但可以保留显式）
        # 判断是否为该系列最新的 alpine 版本
        if is_latest_alpine "$major_minor" "$os_variant"; then
            # 无补丁版本号的 alpine 别名
            aliases+=("${full_version}-${target_type}-alpine")
            aliases+=("${major_minor}-${target_type}-alpine")
            # 对于 cli 变体，额外生成顶级 alpine 别名（不带 -cli）
            if [[ "$target_type" == "cli" ]]; then
                # 带具体 alpine 版本的顶级别名
                aliases+=("${full_version}-${os_variant}")   # 8.4.21-alpine3.23
                aliases+=("${major_minor}-${os_variant}")    # 8.4-alpine3.23
                # 无具体版本号的顶级别名（官方：8.4.21-alpine, 8.4-alpine）
                aliases+=("${full_version}-alpine")          # 8.4.21-alpine
                aliases+=("${major_minor}-alpine")           # 8.4-alpine
            fi
        fi
    fi

    # 去重并推送所有别名
    for alias in $(echo "${aliases[@]}" | tr ' ' '\n' | sort -u); do
        docker tag "${image_name}:${specific_tag}" "${image_name}:${alias}"
        docker push "${image_name}:${alias}"
        log INFO "Pushed alias: ${alias}"
    done
}

# 处理一个主版本（如 8.4）
process_version() {
    local major_minor="$1"
    local full_version=$(get_full_version "$major_minor")
    if [[ -z "$full_version" || "$full_version" == "null" ]]; then
        log ERROR "Full version not found for $major_minor in versions.json"
        exit 1
    fi
    log INFO "Processing $major_minor (full version: $full_version)"

    local dockerfiles=$(find "./template/$major_minor" -name 'Dockerfile' -type f)
    for dockerfile in $dockerfiles; do
        local build_dir=$(dirname "$dockerfile")
        build_and_push_variant "$major_minor" "$full_version" "$build_dir"
    done
}

# 主入口（保持与 ci.sh 的调用一致）
process() {
    local version="$1"
    if [[ ! -d "./template/$version" ]]; then
        log ERROR "template/$version directory not found"
        return 1
    fi
    process_version "$version"
}

process "$1"
