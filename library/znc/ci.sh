#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

PROCESSED_FILE="processed_versions.txt"
PROJECT_DIR="$(pwd)"

main() {
    log "Fetching latest version..."
    VERSION=$(./fetch_versions.sh)
    if [ -z "$VERSION" ]; then
        log "ERROR: Failed to get latest version"
        exit 1
    fi
    log "Latest version: $VERSION"

    if grep -Fxq "$VERSION" "$PROCESSED_FILE" 2>/dev/null; then
        log "Version $VERSION already built, skipping."
        exit 0
    fi

    log "Processing version $VERSION..."
    ./process_version.sh "$VERSION"

    echo "$VERSION" >> "$PROCESSED_FILE"
    log "Recorded $VERSION in $PROCESSED_FILE"

    # 可选 Git 提交
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$PROCESSED_FILE" 2>/dev/null || true
        if ! git diff --cached --quiet; then
            git config user.name "Huang Yang" || true
            git config user.email "huangyang@loongson.cn" || true
            git commit -m "Update ZNC to $VERSION" || true
            git pull --rebase || true
            git push origin main || true
        fi
    fi

    log "CI finished."
}

main
