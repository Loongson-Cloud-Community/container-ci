#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

PROCESSED_FILE="processed_versions.txt"
REPO_URL="https://github.com/TimWolla/docker-spiped.git"
TEMP_DIR="$(mktemp -d)"
REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="spiped"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

get_version_from_dockerfile() {
    local dockerfile="$1"
    sed -n 's/^ENV[[:space:]]\+SPIPED_VERSION=\([0-9.]\+\).*/\1/p' "$dockerfile"
}

fix_dockerfile() {
    local dockerfile="$1"
    local base_image="$2"
    sed -i "s|^FROM .*$|FROM $base_image|g" "$dockerfile"
}

main() {
    log "Cloning upstream repository..."
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

    # 查找所有版本目录（如 1.6, 1.7 等）
    local version_dirs=()
    for dir in "$TEMP_DIR"/*/; do
        dirname=$(basename "$dir")
        [[ "$dirname" =~ ^[0-9]+\.[0-9]+$ ]] && version_dirs+=("$dirname")
    done

    if [ ${#version_dirs[@]} -eq 0 ]; then
        log "No version directories found."
        exit 1
    fi

    for ver_dir in "${version_dirs[@]}"; do
        local dockerfile_debian="$TEMP_DIR/$ver_dir/Dockerfile"
        [ -f "$dockerfile_debian" ] || continue

        local version=$(get_version_from_dockerfile "$dockerfile_debian")
        log "Detected spiped version $version for directory $ver_dir"

        if grep -Fxq "$version" "$PROCESSED_FILE" 2>/dev/null; then
            log "Version $version already built, skipping."
            continue
        fi

        # 准备 template 目录
        log "Updating template/$ver_dir..."
        mkdir -p template
        rm -rf "template/$ver_dir"
        cp -r "$TEMP_DIR/$ver_dir" template/

        fix_dockerfile "template/$ver_dir/Dockerfile" "lcr.loongnix.cn/library/debian:trixie-slim"
        if [ -f "template/$ver_dir/alpine/Dockerfile" ]; then
            fix_dockerfile "template/$ver_dir/alpine/Dockerfile" "lcr.loongnix.cn/library/alpine:3.23"
        fi

        local image_name="${REGISTRY}/${ORG}/${PROJ}"
        local tag_prefix="$version"

        # 构建 Debian 变体
        log "Building ${image_name}:${tag_prefix} from template/$ver_dir"
        docker build --network host -t "${image_name}:${tag_prefix}" "template/$ver_dir" || exit 1
        docker push "${image_name}:${tag_prefix}" || exit 1

        local major_minor="${version%.*}"
        local major="${version%%.*}"
        for alias in "$version" "$major_minor" "$major" "latest"; do
            docker tag "${image_name}:${tag_prefix}" "${image_name}:${alias}"
            docker push "${image_name}:${alias}"
            log "Pushed alias: ${alias}"
        done

        # 构建 Alpine 变体
        if [ -d "template/$ver_dir/alpine" ]; then
            log "Building ${image_name}:${tag_prefix}-alpine from template/$ver_dir/alpine"
            docker build --network host -t "${image_name}:${tag_prefix}-alpine" "template/$ver_dir/alpine" || exit 1
            docker push "${image_name}:${tag_prefix}-alpine" || exit 1

            for alias in "${version}-alpine" "${major_minor}-alpine" "${major}-alpine" "alpine"; do
                docker tag "${image_name}:${tag_prefix}-alpine" "${image_name}:${alias}"
                docker push "${image_name}:${alias}"
                log "Pushed alias: ${alias}"
            done
        fi

        echo "$version" >> "$PROCESSED_FILE"
    done

    if git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$PROCESSED_FILE" template/ 2>/dev/null || true
        if ! git diff --cached --quiet; then
            git config user.name "Huang Yang" || true
            git config user.email "huangyang@loongson.cn" || true
            git commit -m "Update spiped images" || true
            git pull --rebase || true
            git push origin main || true
        fi
    fi

    log "CI completed successfully."
}

main
