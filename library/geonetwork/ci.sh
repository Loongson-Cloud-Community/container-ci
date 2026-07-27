#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"

source "${SCRIPT_DIR}/lib.sh"

check_dependencies() {
    command -v docker >/dev/null 2>&1 || die "docker is required"
    command -v jq >/dev/null 2>&1 || die "jq is required"
    command -v git >/dev/null 2>&1 || die "git is required"
}

git_commit_changes() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        return 0
    fi
    git reset --quiet
    git add "$PROCESSED_FILE" 2>/dev/null || true
    git add template/4.4.*/ 2>/dev/null || true
    if git diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi
    git config user.name "Huang Yang" || true
    git config user.email "huangyang@loongson.cn" || true
    git commit -m "Update GeoNetwork images" || true
    git pull --rebase || true
    git push origin main || true
    log "Changes committed and pushed"
}

main() {
    check_dependencies

    log "Syncing upstream versions..."
    ./sync_upstream.sh || die "sync_upstream.sh failed"

    IFS=$'\n' versions=($(./fetch_versions.sh))
    if [ -z "$versions" ]; then
        log "No versions need updating"
        exit 0
    fi
    log "Versions to build: ${versions[@]}"

    for version in "${versions[@]}"; do
        log "Processing version $version"
        ./process_version.sh "$version" || die "process_version.sh failed for $version"
        update_versions_file "$PROCESSED_FILE" "$version"
    done

#    git_commit_changes
    log "CI finished successfully"
}

main
