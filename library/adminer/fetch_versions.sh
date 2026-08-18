#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
UPSTREAM_REPO="https://github.com/TimWolla/docker-adminer.git"
UPSTREAM_BRANCH="master"
VERSIONS_JSON="${SCRIPT_DIR}/versions.json"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

sync_upstream() {
    log "Syncing upstream repository to template/..."
    if [ -d "$TEMPLATE_DIR/.git" ]; then
        cd "$TEMPLATE_DIR"
        git fetch --depth 1 origin "$UPSTREAM_BRANCH" || true
        git reset --hard "origin/$UPSTREAM_BRANCH" || true
        cd "$SCRIPT_DIR"
    else
        rm -rf "$TEMPLATE_DIR"
        git clone --depth 1 --branch "$UPSTREAM_BRANCH" "$UPSTREAM_REPO" "$TEMPLATE_DIR" || die "Failed to clone upstream repository"
    fi
    log "Upstream synced successfully"
}

get_versions_from_upstream() {
    log "Detecting versions from upstream..."
    
    echo "{" > "$VERSIONS_JSON"
    local first=true
    
    for major in 4 5; do
        local dockerfile="$TEMPLATE_DIR/$major/Dockerfile"
        if [ ! -f "$dockerfile" ]; then
            log "WARNING: $dockerfile not found"
            continue
        fi
        
        # 直接匹配 ADMINER_VERSION=，不管前面是什么
        local full_version=$(grep -E "ADMINER_VERSION=" "$dockerfile" | head -1 | sed -n 's/.*ADMINER_VERSION=\([^[:space:]]*\).*/\1/p')
        
        if [ -n "$full_version" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$VERSIONS_JSON"
            fi
            echo "  \"$major\": \"$full_version\"" >> "$VERSIONS_JSON"
            log "Found $major -> $full_version"
        else
            log "WARNING: Cannot extract version from $dockerfile"
        fi
    done
    
    echo "}" >> "$VERSIONS_JSON"
    log "Generated $VERSIONS_JSON"
}

sync_version_dirs() {
    log "Syncing version directories to project root..."
    for dir in 4 5; do
        if [ -L "$SCRIPT_DIR/$dir" ]; then
            rm -f "$SCRIPT_DIR/$dir"
        fi
        if [ -d "$TEMPLATE_DIR/$dir" ]; then
            ln -sf "$TEMPLATE_DIR/$dir" "$SCRIPT_DIR/$dir"
            log "Linked $TEMPLATE_DIR/$dir -> $SCRIPT_DIR/$dir"
        fi
    done
}

main() {
    sync_upstream
    get_versions_from_upstream
    sync_version_dirs
    log "fetch_versions.sh completed successfully"
}

main "$@"
