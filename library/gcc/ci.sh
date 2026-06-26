#!/bin/bash
set -eo pipefail

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="gcc"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

PROCESSED_FILE="processed_versions.txt"

main() {
    # 1. 生成 versions.json 和所有 Dockerfile
    log "Generating GCC Dockerfiles..."
    cd template
    ./update.sh
    cd ..

    # 2. 获取所有主版本号（13-16）
    VERSIONS=$(./fetch_versions.sh)
    if [ -z "$VERSIONS" ]; then
        log "No versions found"
        exit 1
    fi

    # 3. 对每个版本，检查是否已构建（记录具体源码版本号）
    for ver in $VERSIONS; do
        DOCKERFILE="template/$ver/Dockerfile"
        GCC_VERSION=$(grep -E '^ENV GCC_VERSION' "$DOCKERFILE" | awk '{print $3}')
        if [ -z "$GCC_VERSION" ]; then
            log "WARNING: Cannot get GCC_VERSION for $ver, skipping"
            continue
        fi
        # 检查 processed_versions.txt 中是否已记录该具体版本
        if grep -Fxq "$GCC_VERSION" "$PROCESSED_FILE" 2>/dev/null; then
            log "Version $ver ($GCC_VERSION) already built, skipping"
            continue
        fi
        log "Building version $ver ($GCC_VERSION)..."
        ./process_version.sh "$ver"
        echo "$GCC_VERSION" >> "$PROCESSED_FILE"
    done

    # 4. 推送 latest（指向最新版本）
    # 获取最大的主版本号（按数字排序）
    LATEST_VER=$(echo "$VERSIONS" | tail -1)
    if [ -n "$LATEST_VER" ]; then
        LATEST_GCC=$(grep -E '^ENV GCC_VERSION' "template/$LATEST_VER/Dockerfile" | awk '{print $3}')
        if [ -n "$LATEST_GCC" ]; then
            docker tag "${REGISTRY}/${ORG}/${PROJ}:${LATEST_VER}" "${REGISTRY}/${ORG}/${PROJ}:latest"
            docker push "${REGISTRY}/${ORG}/${PROJ}:latest"
            log "Pushed latest (pointing to $LATEST_GCC)"
        fi
    fi

    # 5. Git 提交
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$PROCESSED_FILE" template/ 2>/dev/null || true
        if ! git diff --cached --quiet; then
            git config user.name "Huang Yang" || true
            git config user.email "huangyang@loongson.cn" || true
            git commit -m "Update GCC images" || true
            git pull --rebase || true
            git push origin main || true
        fi
    fi

    log "CI finished."
}

main
