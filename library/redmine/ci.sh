#!/bin/bash
set -eo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

PROCESSED_FILE="processed_versions.txt"
IGNORE_FILE="ignore_versions.txt"

main() {
    if [ ! -d "template" ]; then
        log "ERROR: template directory not found"
        exit 1
    fi
    cd template
    if [ ! -x "./update.sh" ]; then
        log "ERROR: template/update.sh not found"
        exit 1
    fi
    log "Generating versions.json and Dockerfiles..."
    ./update.sh
    cd ..

    versions_json="template/versions.json"
    versions=$(jq -r 'keys[]' "$versions_json")
    if [ -z "$versions" ]; then
        log "No versions found"
        exit 1
    fi

    declare -A current_versions
    for ver in $versions; do
        current_versions["$ver"]=$(jq -r ".[\"$ver\"].version" "$versions_json")
    done

    declare -A processed_versions
    if [ -f "$PROCESSED_FILE" ]; then
        while IFS=: read -r major full; do
            processed_versions["$major"]="$full"
        done < "$PROCESSED_FILE"
    fi

    declare -A ignore_versions
    if [ -f "$IGNORE_FILE" ]; then
        while read -r line; do ignore_versions["$line"]=1; done < "$IGNORE_FILE"
    fi

    to_build=()
    for ver in "${!current_versions[@]}"; do
        if [ -n "${ignore_versions[$ver]}" ]; then
            log "Ignoring $ver"
            continue
        fi
        new="${current_versions[$ver]}"
        old="${processed_versions[$ver]}"
        if [ -z "$old" ]; then
            log "New version $ver ($new)"
            to_build+=("$ver")
        elif [ "$old" != "$new" ]; then
            log "Version $ver updated from $old to $new"
            to_build+=("$ver")
        else
            log "Version $ver already at $new"
        fi
    done

    if [ ${#to_build[@]} -eq 0 ]; then
        log "Nothing to build"
        exit 0
    fi

    for ver in "${to_build[@]}"; do
        log "Processing $ver"
        ./process_version.sh "$ver"
        sed -i "/^$ver:/d" "$PROCESSED_FILE" 2>/dev/null || true
        echo "$ver:${current_versions[$ver]}" >> "$PROCESSED_FILE"
    done

    commit_msg="Update Redmine: $(for v in "${to_build[@]}"; do echo -n "${current_versions[$v]} "; done)"
    git add "$PROCESSED_FILE" "$versions_json" template/ 2>/dev/null || true
    if ! git diff --cached --quiet; then
        git config user.name "CI Bot" || true
        git config user.email "ci@loongson.cn" || true
        git commit -m "$commit_msg" || true
        git pull --rebase || true
        git push origin main || true
    fi
    log "Done"
}

main
