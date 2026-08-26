#!/bin/bash
# lib.sh - 公共函数库

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

# 检查命令是否存在
check_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"
}

# 检查所有依赖
check_dependencies() {
    check_cmd jq
    check_cmd docker
    check_cmd git
    check_cmd sed
    check_cmd grep
    check_cmd awk
}
