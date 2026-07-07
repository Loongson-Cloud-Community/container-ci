#!/bin/bash
set -eo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/template" || exit 1

MAJORS=("12.1" "12.0" "10" "9.4")
VARIANTS=("jdk17" "jdk17-alpine" "jdk21" "jdk21-alpine" "jdk25" "jdk25-alpine")

ensure_variant_dir() {
    local major="$1"
    local variant="$2"
    local dir="eclipse-temurin/$major/$variant"
    mkdir -p "$dir"
    local java_version="${variant%%-*}"
    java_version="${java_version#jdk}"
    local base_tag="${java_version}-jdk"
    if [[ "$variant" == *-alpine ]]; then
        base_tag="${base_tag}-alpine"
    fi
    # 强制写入短格式，确保 update.sh 能提取标签
    echo "FROM eclipse-temurin:$base_tag" > "$dir/Dockerfile"
    log "Created/overwrote initial Dockerfile for $dir with FROM eclipse-temurin:$base_tag"
}

for major in "${MAJORS[@]}"; do
    for variant in "${VARIANTS[@]}"; do
        ensure_variant_dir "$major" "$variant"
        log "Updating eclipse-temurin/$major/$variant"
        ./update.sh "eclipse-temurin/$major/$variant" >/dev/null 2>&1
    done
done

# 修正基础镜像地址为私有仓库
find eclipse-temurin -name "Dockerfile" -exec sed -i 's|^FROM eclipse-temurin:|FROM lcr.loongnix.cn/library/eclipse-temurin:|' {} \;
log "Fixed base image repository in all Dockerfiles"

# 生成 versions.json
VERSIONS_JSON="$SCRIPT_DIR/versions.json"
rm -f "$VERSIONS_JSON"
echo "{" > "$VERSIONS_JSON"
first=true
for major in "${MAJORS[@]}"; do
    sample_dir="eclipse-temurin/$major/jdk17"
    if [ -f "$sample_dir/Dockerfile" ]; then
        full_version=$(grep "ENV JETTY_VERSION" "$sample_dir/Dockerfile" | awk '{print $3}')
        if [ -n "$full_version" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$VERSIONS_JSON"
            fi
            echo "  \"$major\": \"$full_version\"" >> "$VERSIONS_JSON"
            log "Found $major -> $full_version"
        else
            log "WARNING: Cannot extract version for $major"
        fi
    else
        log "WARNING: $sample_dir/Dockerfile not found"
    fi
done
echo "}" >> "$VERSIONS_JSON"

log "Generated $VERSIONS_JSON"
