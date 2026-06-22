#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="yourls"
REPO_URL="https://github.com/YOURLS/containers.git"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
PROJECT_ROOT="$PWD"   # 保存项目根目录
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

log "Cloning YOURLS containers repository..."
git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

cd "$TEMP_DIR/images/yourls"

# 修改模板中的基础镜像
log "Modifying Dockerfile.template..."
sed -i 's|^FROM php:8.5-%%VARIANT%%|FROM lcr.loongnix.cn/library/php:8.5-%%VARIANT%%|g' Dockerfile.template

# 下载源码并计算 SHA256
log "Downloading source for version $VERSION..."
TARBALL_URL="https://github.com/YOURLS/YOURLS/archive/${VERSION}.tar.gz"
TARBALL_FILE="/tmp/yourls-${VERSION}.tar.gz"
curl -fsSL --retry 3 --retry-delay 2 -o "$TARBALL_FILE" "$TARBALL_URL"
if [ ! -f "$TARBALL_FILE" ] || [ ! -s "$TARBALL_FILE" ]; then
    log "ERROR: Failed to download tarball from $TARBALL_URL"
    exit 1
fi
SHA256=$(sha256sum "$TARBALL_FILE" | awk '{print $1}')
rm -f "$TARBALL_FILE"

# 更新版本和 SHA256
sed -i "s|^ARG YOURLS_VERSION=\".*\"|ARG YOURLS_VERSION=\"$VERSION\"|g" Dockerfile.template
sed -i "s|^ARG YOURLS_SHA256=\".*\"|ARG YOURLS_SHA256=\"$SHA256\"|g" Dockerfile.template

# 生成变体 Dockerfile
log "Generating variant Dockerfiles..."
./bin/generate-variants.sh .

# 拷贝并重命名到项目根目录下的 template 目录
log "Copying variant Dockerfiles to project template directory..."
PROJECT_TEMPLATE="$PROJECT_ROOT/template"
rm -rf "$PROJECT_TEMPLATE"
mkdir -p "$PROJECT_TEMPLATE"
for variant in apache fpm fpm-alpine; do
    if [ -d ".$variant" ]; then
        cp -r ".$variant" "$PROJECT_TEMPLATE/$variant"
        log "Copied .$variant to $PROJECT_TEMPLATE/$variant"
    else
        log "ERROR: .$variant not found"
        exit 1
    fi
done

IMAGE_NAME="${REGISTRY}/${ORG}/${PROJ}"
MAJOR_MINOR="${VERSION%.*}"
MAJOR="${VERSION%%.*}"

# 构建三个变体（使用项目 template 目录）
for variant in apache fpm fpm-alpine; do
    build_dir="$PROJECT_TEMPLATE/$variant"
    log "Building ${IMAGE_NAME}:${VERSION}-${variant} from $build_dir"
    docker build --network host -t "${IMAGE_NAME}:${VERSION}-${variant}" "$build_dir"
    docker push "${IMAGE_NAME}:${VERSION}-${variant}"

    # 生成短标签
    case "$variant" in
        apache)
            for alias in "${VERSION}-apache" "${MAJOR_MINOR}-apache" "${MAJOR}-apache" "apache"; do
                docker tag "${IMAGE_NAME}:${VERSION}-${variant}" "${IMAGE_NAME}:${alias}"
                docker push "${IMAGE_NAME}:${alias}"
                log "Pushed alias: ${alias}"
            done
            # apache 作为默认变体，生成无后缀标签
            for alias in "$VERSION" "$MAJOR_MINOR" "$MAJOR" "latest"; do
                docker tag "${IMAGE_NAME}:${VERSION}-${variant}" "${IMAGE_NAME}:${alias}"
                docker push "${IMAGE_NAME}:${alias}"
                log "Pushed alias: ${alias}"
            done
            ;;
        fpm)
            for alias in "${VERSION}-fpm" "${MAJOR_MINOR}-fpm" "${MAJOR}-fpm" "fpm"; do
                docker tag "${IMAGE_NAME}:${VERSION}-${variant}" "${IMAGE_NAME}:${alias}"
                docker push "${IMAGE_NAME}:${alias}"
                log "Pushed alias: ${alias}"
            done
            ;;
        fpm-alpine)
            for alias in "${VERSION}-fpm-alpine" "${MAJOR_MINOR}-fpm-alpine" "${MAJOR}-fpm-alpine" "fpm-alpine"; do
                docker tag "${IMAGE_NAME}:${VERSION}-${variant}" "${IMAGE_NAME}:${alias}"
                docker push "${IMAGE_NAME}:${alias}"
                log "Pushed alias: ${alias}"
            done
            ;;
    esac
done

log "Completed processing version $VERSION"
