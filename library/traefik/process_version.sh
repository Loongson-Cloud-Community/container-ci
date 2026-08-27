#!/bin/bash
set -eo pipefail

# ============================================================
# 构建并推送 Traefik 指定版本镜像
# 流程：
#   1. 下载并安装最新 Go 版本
#   2. 克隆源码并 checkout 指定 tag
#   3. 应用补丁（若有）
#   4. 编译 LoongArch 二进制
#   5. 准备构建上下文并构建镜像
#   6. 推送标签（版本号、主次版本、主版本，无 latest）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="traefik"
REPO_URL="https://github.com/traefik/traefik.git"
TEMPLATE_BASE="${SCRIPT_DIR}/template"

# ---------- Go 版本配置 ----------
GO_VERSION="1.23.4"
GO_DOWNLOAD_URL="https://go.dev/dl/go${GO_VERSION}.linux-loong64.tar.gz"
GO_INSTALL_DIR="${SCRIPT_DIR}/.go"

# ---------- Docker 基础镜像配置 ----------
ALPINE_VERSION="3.24"
BASE_IMAGE="${REGISTRY}/library/alpine:${ALPINE_VERSION}"

# ---------- 日志 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ---------- 错误处理 ----------
die() {
    log "ERROR: $*" >&2
    exit 1
}

# ---------- 用法 ----------
usage() {
    echo "Usage: $0 <version>"
    echo "Example: $0 3.7.12"
    exit 1
}

# ---------- 校验输入 ----------
validate_input() {
    if [ $# -ne 1 ]; then
        usage
    fi
    VERSION="$1"
    TAG="v$VERSION"
    log "Processing version $VERSION (tag $TAG)"
}

# ---------- 下载并安装 Go ----------
install_go() {
    log "Checking Go installation..."
    
    if [ -f "${GO_INSTALL_DIR}/go/bin/go" ]; then
        local installed_version=$("${GO_INSTALL_DIR}/go/bin/go" version | awk '{print $3}' | sed 's/go//')
        log "Found Go version: ${installed_version}"
        
        if [ "$(printf '%s\n' "$GO_VERSION" "$installed_version" | sort -V | tail -1)" = "$installed_version" ]; then
            log "Go ${installed_version} is already installed and sufficient"
            export PATH="${GO_INSTALL_DIR}/go/bin:${PATH}"
            return 0
        else
            log "Installed Go ${installed_version} is older than required ${GO_VERSION}, downloading new version..."
            rm -rf "${GO_INSTALL_DIR}"
        fi
    fi
    
    log "Downloading Go ${GO_VERSION} for loong64..."
    mkdir -p "${GO_INSTALL_DIR}"
    
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    if ! curl -fsSL -o go.tar.gz "$GO_DOWNLOAD_URL"; then
        log "WARNING: Official download failed, trying Chinese mirror..."
        GO_DOWNLOAD_URL="https://golang.google.cn/dl/go${GO_VERSION}.linux-loong64.tar.gz"
        curl -fsSL -o go.tar.gz "$GO_DOWNLOAD_URL" || die "Failed to download Go from both official and mirror"
    fi
    
    log "Extracting Go to ${GO_INSTALL_DIR}..."
    tar -xzf go.tar.gz -C "${GO_INSTALL_DIR}" || die "Failed to extract Go"
    
    cd - >/dev/null
    rm -rf "$tmp_dir"
    
    if [ -f "${GO_INSTALL_DIR}/go/bin/go" ]; then
        local installed_version=$("${GO_INSTALL_DIR}/go/bin/go" version)
        log "Go installed successfully: ${installed_version}"
    else
        die "Go installation failed"
    fi
    
    export PATH="${GO_INSTALL_DIR}/go/bin:${PATH}"
    export GOROOT="${GO_INSTALL_DIR}/go"
    log "Go is now available in PATH: $(which go)"
}

# ---------- 克隆仓库 ----------
clone_repo() {
    local work_dir="$1"
    log "Cloning Traefik repository (tag $TAG)..."
    git clone --depth 1 --branch "$TAG" "$REPO_URL" "$work_dir" || die "git clone failed"
}

# ---------- 应用补丁 ----------
apply_patches() {
    local work_dir="$1"
    local patches_dir="${SCRIPT_DIR}/patches"
    if [ ! -d "$patches_dir" ]; then
        log "WARNING: Patches directory not found, skipping"
        return 0
    fi
    log "Applying patches from $patches_dir..."
    cd "$work_dir" || die "Cannot enter work directory"
    for patch_file in "$patches_dir"/*.patch; do
        if [ -f "$patch_file" ]; then
            log "Applying $patch_file"
            patch -p1 < "$patch_file" || die "Failed to apply $patch_file"
        fi
    done
    cd - >/dev/null || die "Cannot return"
}

# ---------- 构建二进制 ----------
build_binary() {
    local work_dir="$1"
    log "Building Traefik binary for loong64..."
    cd "$work_dir" || die "Cannot enter work directory"
    
    # 使用新安装的 Go
    export PATH="${GO_INSTALL_DIR}/go/bin:${PATH}"
    export GOROOT="${GO_INSTALL_DIR}/go"
    export GOOS=linux
    export GOARCH=loong64
    export CGO_ENABLED=0
    export GO111MODULE=on
    export GOPROXY="https://goproxy.cn,direct"
    export GONOSUMDB="*"
    
    local go_version=$(go version)
    log "Using Go: $go_version"
    
    # 方法1：使用 make
    log "Method 1: Using make binary-linux-loong64..."
    if make binary-linux-loong64 2>&1; then
        log "Make build successful!"
        cd - >/dev/null || die "Cannot return"
        return 0
    fi
    
    # 方法2：直接构建
    log "Method 2: Direct go build..."
    
    local build_date=$(date +'%Y-%m-%d_%H:%M:%S')
    
    go build \
        -mod=mod \
        -ldflags "-s -w \
            -X github.com/traefik/traefik/v3/pkg/version.Version=$VERSION \
            -X github.com/traefik/traefik/v3/pkg/version.Codename=unknown \
            -X github.com/traefik/traefik/v3/pkg/version.BuildDate=$build_date" \
        -o "./dist/linux/loong64/traefik" \
        ./cmd/traefik || die "go build failed"
    
    log "Build successful!"
    cd - >/dev/null || die "Cannot return"
}

# ---------- 准备构建上下文 ----------
prepare_build_context() {
    local work_dir="$1"
    log "Preparing build context in template directory..."

    local version_dir="${TEMPLATE_BASE}/${VERSION}"
    mkdir -p "$version_dir"

    # 复制二进制文件
    local binary_src="${work_dir}/dist/linux/loong64/traefik"
    if [ ! -f "$binary_src" ]; then
        binary_src="${work_dir}/dist/traefik"
        if [ ! -f "$binary_src" ]; then
            die "Binary not found in dist directory"
        fi
    fi
    
    cp "$binary_src" "${version_dir}/traefik" || die "Cannot copy traefik binary"
    chmod +x "${version_dir}/traefik"

    # 检查并复制 static 目录
    local has_static=false
    if [ -d "${work_dir}/webui/static" ]; then
        cp -r "${work_dir}/webui/static" "${version_dir}/" 2>/dev/null || true
        has_static=true
        log "Copied WebUI static files"
    else
        log "WARNING: WebUI static files not found, skipping"
    fi

    # 开始生成 Dockerfile
    cat > "${version_dir}/Dockerfile" << 'EOF'
FROM lcr.loongnix.cn/library/alpine:3.24

RUN apk add --no-cache ca-certificates tzdata

COPY traefik /usr/local/bin/

EOF

    # 如果有 static 目录，添加 COPY 指令
    if [ "$has_static" = true ]; then
        cat >> "${version_dir}/Dockerfile" << 'EOF'
COPY static /webui/static/

EOF
    fi

    # 添加剩余指令
    cat >> "${version_dir}/Dockerfile" << 'EOF'
RUN adduser -D -g '' traefik

USER traefik

EXPOSE 80 443 8080

ENTRYPOINT ["/usr/local/bin/traefik"]
EOF

    log "Dockerfile created with base image: lcr.loongnix.cn/library/alpine:3.24"
    log "Build context prepared in ${version_dir}"
}

# ---------- 构建并推送镜像 ----------
build_and_push() {
    local version_dir="${TEMPLATE_BASE}/${VERSION}"
    local image_name="${REGISTRY}/${ORG}/${PROJ}"
    local version="$VERSION"
    local major_minor="${version%.*}"
    local major="${version%%.*}"

    log "Building ${image_name}:${version}"
    docker build --no-cache --network host -t "${image_name}:${version}" "$version_dir" || die "docker build failed"

    # 推送标签
    local tags=("$version" "$major_minor" "$major")
    for tag in "${tags[@]}"; do
        log "Tagging ${image_name}:${tag}"
        docker tag "${image_name}:${version}" "${image_name}:${tag}" || die "docker tag failed for $tag"
        log "Pushing ${image_name}:${tag}"
        docker push "${image_name}:${tag}" || die "docker push failed for $tag"
    done

    log "Push completed for version $version"
}

# ---------- 清理 ----------
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log "Cleaned up temporary directory"
    fi
}

# ---------- 主函数 ----------
main() {
    validate_input "$@"

    # 安装 Go
    install_go

    TEMP_DIR="$(mktemp -d)"
    trap cleanup EXIT

    clone_repo "$TEMP_DIR"
    apply_patches "$TEMP_DIR"
    build_binary "$TEMP_DIR"
    prepare_build_context "$TEMP_DIR"
    build_and_push

    log "Completed processing version $VERSION"
}

main "$@"
