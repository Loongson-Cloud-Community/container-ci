#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="eclipse-temurin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <major_version>"
    exit 1
fi

MAJOR="$1"

if [ ! -f "$VERSIONS_JSON" ]; then
    log "ERROR: $VERSIONS_JSON not found. Run fetch_versions.sh first."
    exit 1
fi

# 读取版本信息
FULL_VERSION=$(jq -r ".\"$MAJOR\".version" "$VERSIONS_JSON")
TAG_VERSION=$(echo "$FULL_VERSION" | tr '+' '_')

JDK_TAR=$(jq -r ".\"$MAJOR\".tarball.jdk" "$VERSIONS_JSON")
JRE_TAR=$(jq -r ".\"$MAJOR\".tarball.jre" "$VERSIONS_JSON")

if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
    log "ERROR: Cannot find version for $MAJOR in $VERSIONS_JSON"
    exit 1
fi

log "Processing $MAJOR ($FULL_VERSION) -> tag version: $TAG_VERSION"

# 1. 如果 tarball 尚未生成，则生成
if [ -z "$JDK_TAR" ] || [ "$JDK_TAR" = "null" ] || [ -z "$JRE_TAR" ] || [ "$JRE_TAR" = "null" ]; then
    log "Generating tarballs for $MAJOR..."
    ./build-temurin-packages.sh "$MAJOR"
    JDK_TAR=$(jq -r ".\"$MAJOR\".tarball.jdk" "$VERSIONS_JSON")
    JRE_TAR=$(jq -r ".\"$MAJOR\".tarball.jre" "$VERSIONS_JSON")
fi

# 2. 生成 Dockerfile（仅 loongarch64，当前版本）
log "Generating Dockerfiles for loongarch64, version $MAJOR..."
cd template
python3 generate_dockerfiles.py --version "$MAJOR" --arch loongarch64 --force
cd ..

# 3. 复制 tarball 到各个包含 Dockerfile 的目录（只复制 Debian 变体）
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

# 查找所有 Dockerfile，分别处理 jdk 和 jre
for dockerfile in $(find "template/$MAJOR" -path "*/jdk/*/Dockerfile" -o -path "*/jre/*/Dockerfile" 2>/dev/null || true); do
    variant_dir=$(dirname "$dockerfile")
    if [[ "$variant_dir" == *"/jdk/"* ]]; then
        copy_tarball_to_variant "$variant_dir" "$JDK_TAR"
    else
        copy_tarball_to_variant "$variant_dir" "$JRE_TAR"
    fi
done

# 4. 构建并推送函数
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
    docker build --network host -t "$base_tag" -f "$dockerfile" "$variant_dir"
    for extra in "${extra_tags[@]}"; do
        docker tag "$base_tag" "$extra"
        log "Tagged $base_tag as $extra"
    done
    docker push "$base_tag"
    for extra in "${extra_tags[@]}"; do
        docker push "$extra"
    done
}

# 5. 为每个变体生成标签并构建
generate_tags() {
    local variant_type="$1"
    local base_image="$2"
    local major="$3"
    local tag_version="$4"
    local registry_org_proj="$5"

    local base_tag=""
    local extra_tags=()

    if [[ "$base_image" == debian/* ]]; then
        if [ "$variant_type" = "jdk" ]; then
            base_tag="${registry_org_proj}:${major}"
            extra_tags+=(
                "${registry_org_proj}:${major}-jdk"
                "${registry_org_proj}:${tag_version}"
                "${registry_org_proj}:${tag_version}-jdk"
            )
        else # jre
            base_tag="${registry_org_proj}:${major}-jre"
            extra_tags+=(
                "${registry_org_proj}:${tag_version}-jre"
            )
        fi
    elif [[ "$base_image" == alpine/* ]]; then
        if [ "$variant_type" = "jdk" ]; then
            base_tag="${registry_org_proj}:${major}-alpine"
            extra_tags+=(
                "${registry_org_proj}:${tag_version}-alpine"
            )
        else # jre
            base_tag="${registry_org_proj}:${major}-alpine-jre"
            extra_tags+=(
                "${registry_org_proj}:${tag_version}-alpine-jre"
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

# 遍历所有 Dockerfile，构建
for dockerfile in $(find "template/$MAJOR" -path "*/jdk/*/Dockerfile" -o -path "*/jre/*/Dockerfile" 2>/dev/null || true); do
    variant_dir=$(dirname "$dockerfile")
    # 判断类型
    if [[ "$variant_dir" == *"/jdk/"* ]]; then
        variant_type="jdk"
    else
        variant_type="jre"
    fi
    # 提取相对路径（如 debian/forky 或 alpine/3.24）
    base_path=${variant_dir#template/$MAJOR/$variant_type/}
    tag_list=$(generate_tags "$variant_type" "$base_path" "$MAJOR" "$TAG_VERSION" "${REGISTRY}/${ORG}/${PROJ}" || true)
    if [ -z "$tag_list" ]; then
        continue
    fi
    mapfile -t tags_array <<< "$tag_list"
    base_tag="${tags_array[0]}"
    extra_tags=("${tags_array[@]:1}")
    build_and_push "$variant_dir" "$base_tag" "${extra_tags[@]}" || true
done

# 清理 tarball
rm -f "/tmp/$JDK_TAR" "/tmp/$JRE_TAR" || true
log "Cleaned up tarballs for $MAJOR"

log "Completed $MAJOR ($FULL_VERSION)"
