#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROCESSED_FILE="${SCRIPT_DIR}/processed_versions.txt"
IGNORE_FILE="${SCRIPT_DIR}/ignore_versions.txt"
TEMPLATE_DIR="${SCRIPT_DIR}/template"

get_all_versions() {
    find "$TEMPLATE_DIR" -maxdepth 1 -type d -name '4.4.*' -exec basename {} \; | sort -V
}

filter_ignored() {
    if [ -f "$IGNORE_FILE" ]; then
        grep -Fxv -f "$IGNORE_FILE"
    else
        cat
    fi
}

filter_processed() {
    if [ -f "$PROCESSED_FILE" ]; then
        grep -Fxv -f "$PROCESSED_FILE"
    else
        cat
    fi
}

main() {
    get_all_versions \
        | filter_ignored \
        | filter_processed \
        | sort -V
}

main
