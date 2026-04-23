#!/bin/bash
set -eo pipefail

source "$(dirname "$0")/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='library'
readonly PROJ='perl'
readonly TEMPLATE_DIR="$(dirname "$0")/template"

# 版本号标准化：5.42.2 -> 5.042.002
normalize_version_for_dir() {
    local ver="$1"
    IFS='.' read -ra parts <<< "$ver"
    printf "%d.%03d.%03d" "${parts[0]}" "${parts[1]}" "${parts[2]}"
}

# 从目录名解析组件：5.042.002-main,threaded-forky -> 5.42.2,main,threaded,forky
parse_dirname() {
    local dirname="$1"
    if [[ "$dirname" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(.*)-([a-z]+)$ ]]; then
        local ver_dir="${BASH_REMATCH[1]}"
        local variant="${BASH_REMATCH[2]}"
        local codename="${BASH_REMATCH[3]}"
        local version
        version=$(echo "$ver_dir" | awk -F. '{printf "%d.%d.%d", $1, $2+0, $3+0}')
        echo "$version" "$variant" "$codename"
    else
        log ERROR "Cannot parse dirname: $dirname"
        return 1
    fi
}

# 生成标签列表（与官方 Perl 镜像标签结构一致）
generate_tags() {
    local version="$1"      # 5.42.2
    local variant="$2"      # main / slim / main,threaded / slim,threaded
    local codename="$3"     # forky

    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"
    local major_minor="$major.$minor"
    local major_only="$major"

    # 确定变体后缀
    local base_variant=""
    local has_threaded=0
    local has_slim=0

    if [[ "$variant" == *",threaded"* ]] || [[ "$variant" == "threaded" ]]; then
        has_threaded=1
    fi
    if [[ "$variant" == *"slim"* ]]; then
        has_slim=1
    fi

    if [[ $has_slim -eq 1 ]] && [[ $has_threaded -eq 1 ]]; then
        base_variant="slim-threaded"
    elif [[ $has_slim -eq 1 ]]; then
        base_variant="slim"
    elif [[ $has_threaded -eq 1 ]]; then
        base_variant="threaded"
    else
        base_variant=""
    fi

    # 判断是否为开发版（奇数次版本号）
    local is_devel=0
    if (( minor % 2 == 1 )); then
        is_devel=1
    fi

    local tags=()

    # 基础标签（不带发行版代号）
    if [[ -z "$base_variant" ]]; then
        tags+=("$version" "$major_minor" "$major_only")
        if [[ $is_devel -eq 1 ]]; then
            tags+=("devel")
        else
            tags+=("latest" "stable")
        fi
    else
        tags+=("$version-$base_variant" "$major_minor-$base_variant" "$major_only-$base_variant" "$base_variant")
        if [[ $is_devel -eq 1 ]]; then
            tags+=("devel-$base_variant")
        else
            tags+=("stable-$base_variant")
        fi
    fi

    # 带发行版代号的标签
    if [[ -z "$base_variant" ]]; then
        tags+=("$version-$codename" "$major_minor-$codename" "$major_only-$codename" "$codename")
        if [[ $is_devel -eq 1 ]]; then
            tags+=("devel-$codename")
        else
            tags+=("stable-$codename")
        fi
    else
        tags+=("$version-$base_variant-$codename" "$major_minor-$base_variant-$codename" "$major_only-$base_variant-$codename" "$base_variant-$codename")
        if [[ $is_devel -eq 1 ]]; then
            tags+=("devel-$base_variant-$codename")
        else
            tags+=("stable-$base_variant-$codename")
        fi
    fi

    printf "%s\n" "${tags[@]}" | sort -u
}

# 构建并推送单个变体目录的镜像
build_and_push() {
    local dir="$1"
    local version="$2"
    local variant="$3"
    local codename="$4"

    local dockerfile="$dir/Dockerfile"
    if [[ ! -f "$dockerfile" ]]; then
        log WARN "Skipping $dir: no Dockerfile"
        return 0
    fi

    # 将逗号替换为连字符，确保主标签合法
    local safe_variant="${variant//,/-}"
    local primary_tag="${REGISTRY}/${ORG}/${PROJ}:${version}-${safe_variant}-${codename}"

    log INFO "Building image: $primary_tag"
    if ! docker build -t "$primary_tag" "$dir"; then
        log ERROR "Build failed for $primary_tag"
        return 1
    fi

    # 冒烟测试：运行 perl -v 验证镜像可用性
    log INFO "Smoke testing image: $primary_tag"
    if ! docker run --rm "$primary_tag" perl -v > /dev/null; then
        log ERROR "Smoke test failed for $primary_tag"
        return 1
    fi
    log INFO "Smoke test passed"    

    # 生成附加标签并打标签
    local tag_list
    tag_list=$(generate_tags "$version" "$variant" "$codename")
    local tags=()
    while IFS= read -r t; do
        [[ -n "$t" ]] && tags+=("$t")
    done <<< "$tag_list"

    for t in "${tags[@]}"; do
        local full_tag="${REGISTRY}/${ORG}/${PROJ}:$t"
        if [[ "$full_tag" != "$primary_tag" ]]; then
            log INFO "Tagging: $full_tag"
            docker tag "$primary_tag" "$full_tag"
        fi
    done

    # 推送所有标签（包括主标签）
    local all_tags=("$primary_tag")
    for t in "${tags[@]}"; do
        all_tags+=("${REGISTRY}/${ORG}/${PROJ}:$t")
    done

    local unique_tags
    unique_tags=$(printf "%s\n" "${all_tags[@]}" | sort -u)

    while IFS= read -r t; do
        log INFO "Pushing: $t"
        if ! docker push "$t"; then
            log ERROR "Push failed for $t"
            return 1
        fi
    done <<< "$unique_tags"

    log INFO "Successfully processed $dir"
}

process() {
    local version="$1"
    local dir_prefix
    dir_prefix=$(normalize_version_for_dir "$version")

    log INFO "Processing Perl version $version (dir prefix: $dir_prefix)"

    local dirs
    dirs=$(find "$TEMPLATE_DIR" -maxdepth 1 -type d -name "${dir_prefix}-*" | sort)

    if [[ -z "$dirs" ]]; then
        log ERROR "No directories found for version $version in $TEMPLATE_DIR"
        return 1
    fi

    for dir in $dirs; do
        local dirname
        dirname=$(basename "$dir")
        local parsed
        parsed=$(parse_dirname "$dirname") || continue
        read -r parsed_version parsed_variant parsed_codename <<< "$parsed"
        build_and_push "$dir" "$parsed_version" "$parsed_variant" "$parsed_codename"
    done

    log INFO "Finished processing version $version"
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <version>" >&2
    exit 1
fi

process "$1"
