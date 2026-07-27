#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_DIR="${SCRIPT_DIR}/.upstream"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
UPSTREAM_REPO="https://github.com/geonetwork/docker-geonetwork.git"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "ERROR: $*"; exit 1; }

sync_upstream() {
    rm -rf "$UPSTREAM_DIR"
    mkdir -p "$UPSTREAM_DIR"
    cd "$UPSTREAM_DIR"

    git init
    git remote add origin "$UPSTREAM_REPO"
    git config core.sparseCheckout true

    # 只检出 4.4.x 版本（支持通配符）
    echo "4.4.*" >> .git/info/sparse-checkout

    git pull --depth 1 origin main || die "git pull failed"
    cd "$SCRIPT_DIR"
}

copy_new_versions() {
    mkdir -p "$TEMPLATE_DIR"
    local new_versions=()
    local local_versions=$(find "$TEMPLATE_DIR" -maxdepth 1 -type d -name '4.4.*' -exec basename {} \; 2>/dev/null || true)
    local upstream_versions=$(find "$UPSTREAM_DIR" -maxdepth 1 -type d -name '4.4.*' -exec basename {} \; 2>/dev/null || true)

    for version in $upstream_versions; do
        if ! echo "$local_versions" | grep -Fxq "$version"; then
            new_versions+=("$version")
            log "New version detected: $version"
            cp -r "$UPSTREAM_DIR/$version" "$TEMPLATE_DIR/" || die "Failed to copy $version"
        fi
    done

    if [ ${#new_versions[@]} -eq 0 ]; then
        log "No new 4.4.x versions found"
    else
        log "Synced new versions: ${new_versions[*]}"
    fi
}

main() {
    sync_upstream
    copy_new_versions
    log "Upstream sync completed"
}

main "$@"
