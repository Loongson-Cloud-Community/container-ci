#!/bin/bash

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

update_versions_file() {
    local version_file="$1"
    local new_version="$2"
    local tmp_file="${version_file}.tmp"

    [[ -z "$new_version" ]] && die "Empty version"
    [[ -z "$version_file" ]] && die "Missing version file"

    touch "$version_file"
    {
        echo "$new_version"
        cat "$version_file"
    } | sort -Vu > "$tmp_file" || return 1

    if ! cmp -s "$version_file" "$tmp_file"; then
        mv "$tmp_file" "$version_file" || return 1
        log "Added ${new_version} to ${version_file}"
    else
        rm -f "$tmp_file"
        log "No changes to ${version_file}"
    fi
}
