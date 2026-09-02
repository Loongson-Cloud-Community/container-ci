#!/bin/bash

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'

log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case "$level" in
        INFO) color="${GREEN}" ;;
        WARN) color="${YELLOW}" ;;
        ERROR) color="${RED}" ;;
        *) color="${NC}" ;;
    esac
    echo -e "${color}[${timestamp}] [${level}] ${message}${NC}" >&2
}

die() {
    log ERROR "$*" >&2
    exit 1
}

check_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"
}

check_dependencies() {
    check_cmd jq
    check_cmd docker
    check_cmd git
    check_cmd sed
    check_cmd grep
    check_cmd awk
    check_cmd find
    check_cmd wget
}

# 更新版本记录文件（去重排序）
update_versions_file() {
    local version_file="$1"
    local new_version="$2"
    local tmp_file="${version_file}.tmp"

    [[ -z "$new_version" ]] && { echo "ERROR: Empty version" >&2; return 1; }
    [[ -z "$version_file" ]] && { echo "ERROR: Missing version file" >&2; return 1; }

    touch "$version_file"

    {
        echo "$new_version"
        cat "$version_file"
    } | sort -Vu >"$tmp_file" || return 1

    if ! cmp -s "$version_file" "$tmp_file"; then
        mv "$tmp_file" "$version_file" || return 1
        echo "Add ${new_version} into ${version_file}"
    else
        rm -f "$tmp_file"
        echo "No changes"
    fi
}
