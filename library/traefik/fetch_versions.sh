#!/bin/bash
set -eo pipefail

# ============================================================
# 从 GitHub API 获取 Traefik 最新稳定版本号
# 输出：版本号（如 2.11.0）
# ============================================================

REPO_URL="https://api.github.com/repos/traefik/traefik/releases/latest"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v jq >/dev/null 2>&1 || die "jq is required"

curl -fsSL "$REPO_URL" | jq -r '.tag_name' | sed 's/^v//'
