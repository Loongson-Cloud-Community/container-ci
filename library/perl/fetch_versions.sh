#!/bin/bash
set -eo pipefail

fetch_versions() {
    local template_dir="$(dirname "$0")/template"
    if [[ ! -d "$template_dir" ]]; then
        echo "ERROR: template directory not found" >&2
        exit 1
    fi

    # 提取版本号并去重排序
    find "$template_dir" -maxdepth 1 -type d -name '[0-9]*' -printf '%f\n' \
        | sed -E 's/^([0-9]+)\.0*([0-9]+)\.0*([0-9]+)-.*$/\1.\2.\3/' \
        | sort -uV \
        | grep -Fxv -f ignore_versions.txt \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; }
}

fetch_versions
