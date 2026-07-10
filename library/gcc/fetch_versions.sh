#!/bin/bash
set -eo pipefail

# ============================================================
# 获取所有主版本号（从 template/versions.json 读取）
# 输出：以换行分隔的版本号列表（如 13 14 15 16）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

if [ ! -f "$VERSIONS_JSON" ]; then
    die "$VERSIONS_JSON not found"
fi

jq -r 'keys[]' "$VERSIONS_JSON" | sort -n
