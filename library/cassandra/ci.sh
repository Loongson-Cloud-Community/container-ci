#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"
TEMPLATE_DIR="${SCRIPT_DIR}/template"
VERSIONS_JSON="${TEMPLATE_DIR}/versions.json"

source "${SCRIPT_DIR}/lib.sh"

check_dependencies() {
    command -v jq >/dev/null 2>&1 || die "jq is required"
    command -v docker >/dev/null 2>&1 || die "docker is required"
    command -v git >/dev/null 2>&1 || die "git is required"
}

update_versions() {
    log "Updating versions and generating Dockerfiles..."
    # 直接调用 template/update.sh（不切换目录，避免路径混淆）
    if [ ! -x "$TEMPLATE_DIR/update.sh" ]; then
        die "update.sh not found or not executable in $TEMPLATE_DIR"
    fi
    "$TEMPLATE_DIR/update.sh"
}

get_all_majors() {
    jq -r 'keys[]' "$VERSIONS_JSON" 2>/dev/null || true
}

is_version_built() {
    local full_version="$1"
    grep -Fxq "$full_version" "$PROCESSED_FILE" 2>/dev/null
}

git_commit_changes() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log "Not a git repository, skipping commit"
        return 0
    fi
    git reset --quiet
    git add "$PROCESSED_FILE" "$VERSIONS_JSON" template/ 2>/dev/null || true
    if git diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi
    git config user.name "Huang Yang" || true
    git config user.email "huangyang@loongson.cn" || true
    local commit_msg="Update Cassandra images: $(jq -r 'to_entries[] | "\(.key)=\(.value.version)"' "$VERSIONS_JSON" | tr '\n' ' ')"
    git commit -m "$commit_msg" || true
    git pull --rebase || true
    git push origin main || true
    log "Changes committed and pushed"
}

main() {
    check_dependencies

    update_versions

    local versions
    versions="$(get_all_majors)"
    if [ -z "$versions" ]; then
        die "No versions found in $VERSIONS_JSON"
    fi

    for ver in $versions; do
        local full_version
        full_version="$(jq -r ".\"$ver\".version" "$VERSIONS_JSON")"
        if [ -z "$full_version" ] || [ "$full_version" = "null" ]; then
            log "WARNING: Skipping $ver due to missing version"
            continue
        fi
        if is_version_built "$full_version"; then
            log "Version $ver ($full_version) already built, skipping"
            continue
        fi
        log "Processing version $ver ($full_version)"
        ./process_version.sh "$ver" || die "process_version.sh failed for $ver"
        echo "$full_version" >> "$PROCESSED_FILE"
    done

    git_commit_changes
    log "CI finished successfully"
}

main "$@"
