#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"

if [ ! -f "$VERSIONS_JSON" ]; then
    echo "ERROR: $VERSIONS_JSON not found. Run update.sh first." >&2
    exit 1
fi

jq -r 'keys[]' "$VERSIONS_JSON"
