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
TAG_VERSION="${FULL_VERSION//+/_}"   # 用于镜像标签，替换 + 为 _
JDK_TAR=$(jq -r ".\"$MAJOR\".tarball.jdk" "$VERSIONS_JSON")
JRE_TAR=$(jq -r ".\"$MAJOR\".tarball.jre" "$VERSIONS_JSON")

if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
    log "ERROR: Cannot find version for $MAJOR in $VERSIONS_JSON"
    exit 1
fi

log "Processing $MAJOR ($FULL_VERSION) (tag: $TAG_VERSION)"

# 1. 如果 tarball 尚未生成，则生成
if [ -z "$JDK_TAR" ] || [ "$JDK_TAR" = "null" ] || [ -z "$JRE_TAR" ] || [ "$JRE_TAR" = "null" ]; then
    log "Generating tarballs for $MAJOR..."
    ./build-temurin-packages.sh "$MAJOR"
    # 重新读取 tarball 文件名
    JDK_TAR=$(jq -r ".\"$MAJOR\".tarball.jdk" "$VERSIONS_JSON")
    JRE_TAR=$(jq -r ".\"$MAJOR\".tarball.jre" "$VERSIONS_JSON")
fi

# 2. 生成 Dockerfile（仅 loongarch64，当前版本）
log "Generating Dockerfiles for loongarch64, version $MAJOR..."
cd template
python3 generate_dockerfiles.py --version "$MAJOR" --arch loongarch64 --force
cd ..

# 3. 复制 tarball 到 Debian 变体目录（保持原名）
prepare_variant() {
    local variant_type="$1"  # jdk 或 jre
    local base_image="$2"    # debian/forky 或 alpine/3.24
    local tar_name="$3"
    
    local variant_dir="$SCRIPT_DIR/template/$MAJOR/$variant_type/$base_image"
    local dockerfile="$variant_dir/Dockerfile"
    
    if [ ! -f "$dockerfile" ]; then
        log "WARNING: $dockerfile not found, skipping"
        return 1
    fi
    
    # 只有 Debian 变体需要复制 tarball（Alpine 使用 apk）
    if [[ "$base_image" == debian/* ]] && [ -n "$tar_name" ] && [ -f "/tmp/$tar_name" ]; then
        cp "/tmp/$tar_name" "$variant_dir/"
        log "Copied /tmp/$tar_name to $variant_dir/"
    elif [[ "$base_image" == alpine/* ]]; then
        log "Alpine variant, skipping tarball copy"
    else
        log "WARNING: /tmp/$tar_name not found or unsupported base image"
        return 1
    fi
}

# 为四个变体复制（Alpine 只调用但不复制）
prepare_variant "jdk" "debian/forky" "$JDK_TAR"
prepare_variant "jre" "debian/forky" "$JRE_TAR"
prepare_variant "jdk" "alpine/3.24" ""   # 不传 tar_name，函数内部会跳过复制
prepare_variant "jre" "alpine/3.24" ""

# 4. 构建并推送函数
build_push() {
    local variant_dir="$1"
    local image_tag="$2"
    local dockerfile="$variant_dir/Dockerfile"
    if [ ! -f "$dockerfile" ]; then
        log "WARNING: $dockerfile not found, skipping"
        return
    fi
    log "Building $image_tag from $dockerfile"
    docker build --network host -t "$image_tag" -f "$dockerfile" "$variant_dir"
    docker push "$image_tag"
}

# 构建四个镜像（使用主版本号标签和完整版本标签）
build_push "$SCRIPT_DIR/template/$MAJOR/jdk/debian/forky" "${REGISTRY}/${ORG}/${PROJ}:${MAJOR}"
docker tag "${REGISTRY}/${ORG}/${PROJ}:${MAJOR}" "${REGISTRY}/${ORG}/${PROJ}:${TAG_VERSION}"
docker push "${REGISTRY}/${ORG}/${PROJ}:${TAG_VERSION}"

build_push "$SCRIPT_DIR/template/$MAJOR/jre/debian/forky" "${REGISTRY}/${ORG}/${PROJ}:${MAJOR}-jre"
docker tag "${REGISTRY}/${ORG}/${PROJ}:${MAJOR}-jre" "${REGISTRY}/${ORG}/${PROJ}:${TAG_VERSION}-jre"
docker push "${REGISTRY}/${ORG}/${PROJ}:${TAG_VERSION}-jre"

build_push "$SCRIPT_DIR/template/$MAJOR/jdk/alpine/3.24" "${REGISTRY}/${ORG}/${PROJ}:${MAJOR}-alpine"
docker tag "${REGISTRY}/${ORG}/${PROJ}:${MAJOR}-alpine" "${REGISTRY}/${ORG}/${PROJ}:${TAG_VERSION}-alpine"
docker push "${REGISTRY}/${ORG}/${PROJ}:${TAG_VERSION}-alpine"

build_push "$SCRIPT_DIR/template/$MAJOR/jre/alpine/3.24" "${REGISTRY}/${ORG}/${PROJ}:${MAJOR}-alpine-jre"
docker tag "${REGISTRY}/${ORG}/${PROJ}:${MAJOR}-alpine-jre" "${REGISTRY}/${ORG}/${PROJ}:${TAG_VERSION}-alpine-jre"
docker push "${REGISTRY}/${ORG}/${PROJ}:${TAG_VERSION}-alpine-jre"

# 清理 tarball（构建完成后删除）
rm -f "/tmp/$JDK_TAR" "/tmp/$JRE_TAR"
log "Cleaned up tarballs for $MAJOR"

log "Completed $MAJOR ($FULL_VERSION)"
