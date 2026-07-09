#!/bin/bash
set -eo pipefail

# ============================================================
# 构建单个 Eclipse Temurin 版本的所有变体，并推送到仓库
# 标签规范：
#   Debian JDK:  <major>-jdk-forky, <tag_version>-jdk-forky
#   Debian JRE:  <major>-jre-forky, <tag_version>-jre-forky
#   Alpine JDK:  <major>-alpine, <tag_version>-alpine, <major>-jdk-alpine, <tag_version>-jdk-alpine
#   Alpine JRE:  <major>-jre-alpine, <tag_version>-jre-alpine
# （不生成 latest 标签）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="eclipse-temurin"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"

# ---------- 日志 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ---------- 错误处理 ----------
die() {
    log "ERROR: $*" >&2
    exit 1
}

# ---------- 检查依赖 ----------
check_dependencies() {
    command -v docker >/dev/null 2>&1 || die "docker is required"
    command -v jq >/dev/null 2>&1 || die "jq is required"
}

# ---------- 构建并推送单个镜像 ----------
build_and_push() {
    local variant_dir="$1"
    local base_tag="$2"
    shift 2
    local extra_tags=("$@")
    local dockerfile="$variant_dir/Dockerfile"

    if [ ! -f "$dockerfile" ]; then
        log "WARNING: $dockerfile not found, skipping"
        return 0
    fi

    log "Building $base_tag from $dockerfile"
    docker build --network host -t "$base_tag" -f "$dockerfile" "$variant_dir" || die "docker build failed for $base_tag"

    for tag in "${extra_tags[@]}"; do
        docker tag "$base_tag" "$tag" || die "docker tag failed for $tag"
        log "Tagged $base_tag as $tag"
    done

    docker push "$base_tag" || die "docker push failed for $base_tag"
    for tag in "${extra_tags[@]}"; do
        docker push "$tag" || die "docker push failed for $tag"
    done

    # 清理该目录下的 tarball
    rm -f "$variant_dir"/*.tar.gz 2>/dev/null || true
    log "Cleaned up tarballs in $variant_dir"
}

# ---------- 生成标签列表 ----------
generate_tags() {
    local variant_type="$1"    # jdk 或 jre
    local base_image="$2"      # debian/forky 或 alpine/3.24 等
    local major="$3"
    local tag_version="$4"
    local registry_org_proj="$5"

    local base_tag=""
    local extra_tags=()

    if [[ "$base_image" == debian/* ]]; then
        if [ "$variant_type" = "jdk" ]; then
            base_tag="${registry_org_proj}:${major}-jdk-forky"
            extra_tags+=(
                "${registry_org_proj}:${tag_version}-jdk-forky"
            )
        else # jre
            base_tag="${registry_org_proj}:${major}-jre-forky"
            extra_tags+=(
                "${registry_org_proj}:${tag_version}-jre-forky"
            )
        fi
    elif [[ "$base_image" == alpine/* ]]; then
        if [ "$variant_type" = "jdk" ]; then
            base_tag="${registry_org_proj}:${major}-alpine"
            extra_tags+=(
                "${registry_org_proj}:${tag_version}-alpine"
                "${registry_org_proj}:${major}-jdk-alpine"
                "${registry_org_proj}:${tag_version}-jdk-alpine"
            )
        else # jre
            base_tag="${registry_org_proj}:${major}-jre-alpine"
            extra_tags+=(
                "${registry_org_proj}:${tag_version}-jre-alpine"
            )
        fi
    else
        log "WARNING: Unknown base image type for $base_image, skipping"
        return 0
    fi

    echo "$base_tag"
    for tag in "${extra_tags[@]}"; do
        echo "$tag"
    done
    return 0
}

# ---------- 复制 tarball 到变体目录 ----------
copy_tarball_to_variant() {
    local variant_dir="$1"
    local tar_name="$2"
    local dockerfile="$variant_dir/Dockerfile"

    if [ ! -f "$dockerfile" ]; then
        return 0
    fi

    if [[ "$variant_dir" == *"/debian/"* ]] && [ -n "$tar_name" ] && [ -f "/tmp/$tar_name" ]; then
        cp "/tmp/$tar_name" "$variant_dir/" || true
        log "Copied /tmp/$tar_name to $variant_dir/"
    elif [[ "$variant_dir" == *"/alpine/"* ]]; then
        log "Alpine variant, skipping tarball copy"
    else
        log "WARNING: Unknown base for $variant_dir, skipping tarball copy"
    fi
    return 0
}

# ---------- 准备 tarball 并生成 Dockerfile ----------
prepare_build() {
    local major="$1"
    local full_version="$2"

    # 确保 tarball 已生成
    local jdk_tar jre_tar
    jdk_tar="$(jq -r ".\"$major\".tarball.jdk" "$VERSIONS_JSON")"
    jre_tar="$(jq -r ".\"$major\".tarball.jre" "$VERSIONS_JSON")"

    if [ -z "$jdk_tar" ] || [ "$jdk_tar" = "null" ] || [ -z "$jre_tar" ] || [ "$jre_tar" = "null" ]; then
        log "Generating tarballs for $major..."
        ./build-temurin-packages.sh "$major" || die "build-temurin-packages.sh failed"
        jdk_tar="$(jq -r ".\"$major\".tarball.jdk" "$VERSIONS_JSON")"
        jre_tar="$(jq -r ".\"$major\".tarball.jre" "$VERSIONS_JSON")"
    fi

    # 生成 Dockerfile（仅 loongarch64）
    log "Generating Dockerfiles for loongarch64, version $major..."
    rm -rf "template/$major"
    cd template || die "Cannot enter template directory"
    python3 generate_dockerfiles.py --version "$major" --arch loongarch64 || die "generate_dockerfiles.py failed"
    cd "$SCRIPT_DIR" || die "Cannot return to script directory"

    # 复制 tarball 到各 Debian 变体目录
    while IFS= read -r dockerfile; do
        local variant_dir="$(dirname "$dockerfile")"
        if [[ "$variant_dir" == *"/jdk/"* ]]; then
            copy_tarball_to_variant "$variant_dir" "$jdk_tar"
        elif [[ "$variant_dir" == *"/jre/"* ]]; then
            copy_tarball_to_variant "$variant_dir" "$jre_tar"
        fi
    done < <(find "template/$major" -path "*/jdk/*/Dockerfile" -o -path "*/jre/*/Dockerfile" 2>/dev/null || true)
}

# ---------- 遍历所有变体并构建 ----------
build_all_variants() {
    local major="$1"
    local tag_version="$2"
    local registry_org_proj="$3"

    while IFS= read -r dockerfile; do
        local variant_dir="$(dirname "$dockerfile")"
        local base_path="${variant_dir#template/$major/}"
        local variant_type=""
        local base_image=""

        if [[ "$base_path" == jdk/* ]]; then
            variant_type="jdk"
            base_image="${base_path#jdk/}"
        elif [[ "$base_path" == jre/* ]]; then
            variant_type="jre"
            base_image="${base_path#jre/}"
        else
            log "WARNING: Unknown variant path $base_path, skipping"
            continue
        fi

        local tag_list
        tag_list="$(generate_tags "$variant_type" "$base_image" "$major" "$tag_version" "$registry_org_proj")" || continue
        mapfile -t tags_array <<< "$tag_list"
        local base_tag="${tags_array[0]}"
        local extra_tags=("${tags_array[@]:1}")

        build_and_push "$variant_dir" "$base_tag" "${extra_tags[@]}"
    done < <(find "template/$major" -path "*/jdk/*/Dockerfile" -o -path "*/jre/*/Dockerfile" 2>/dev/null || true)
}

# ---------- 主函数 ----------
main() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <major_version>"
        exit 1
    fi
    local major="$1"

    check_dependencies

    if [ ! -f "$VERSIONS_JSON" ]; then
        die "$VERSIONS_JSON not found. Run fetch_versions.sh first."
    fi

    local full_version
    full_version="$(jq -r ".\"$major\".version" "$VERSIONS_JSON")"
    if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
        die "Cannot find version for $major in $VERSIONS_JSON"
    fi

    local tag_version
    tag_version="$(echo "$full_version" | tr '+' '_')"
    log "Processing $major ($full_version) -> tag version: $tag_version"

    local registry_org_proj="${REGISTRY}/${ORG}/${PROJ}"

    prepare_build "$major" "$full_version"
    build_all_variants "$major" "$tag_version" "$registry_org_proj"

    # 清理 /tmp 下的 tarball
    local jdk_tar jre_tar
    jdk_tar="$(jq -r ".\"$major\".tarball.jdk" "$VERSIONS_JSON")"
    jre_tar="$(jq -r ".\"$major\".tarball.jre" "$VERSIONS_JSON")"
    rm -f "/tmp/$jdk_tar" "/tmp/$jre_tar" 2>/dev/null || true
    log "Cleaned up /tmp tarballs"

    log "Completed $major ($full_version)"
}

main "$@"
