#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

REGISTRY="lcr.loongnix.cn"
ORG="library"
PROJ="jetty"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_JSON="$SCRIPT_DIR/versions.json"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <major_version>"
    exit 1
fi

MAJOR="$1"

if [ ! -f "$VERSIONS_JSON" ]; then
    log "ERROR: $VERSIONS_JSON not found. Run fetch_versions.sh first."
    exit 1
fi

FULL_VERSION=$(jq -r ".\"$MAJOR\"" "$VERSIONS_JSON")
if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "null" ]; then
    log "ERROR: Cannot find version for $MAJOR in $VERSIONS_JSON"
    exit 1
fi

log "Processing $MAJOR ($FULL_VERSION)"

# 变体列表
VARIANTS=("jdk17" "jdk17-alpine" "jdk21" "jdk21-alpine" "jdk25" "jdk25-alpine")

for variant in "${VARIANTS[@]}"; do
    target_dir="template/eclipse-temurin/$MAJOR/$variant"
    if [ ! -d "$target_dir" ]; then
        log "WARNING: $target_dir does not exist, skipping"
        continue
    fi
    # 标签
    base_tag="${REGISTRY}/${ORG}/${PROJ}:${MAJOR}-${variant}"
    full_tag="${REGISTRY}/${ORG}/${PROJ}:${FULL_VERSION}-${variant}"
    log "Building $base_tag"
    docker build --network host -t "$base_tag" -t "$full_tag" -f "$target_dir/Dockerfile" "$target_dir"
    docker push "$base_tag"
    docker push "$full_tag"
done

log "Completed $MAJOR ($FULL_VERSION)"
