#!/bin/bash
set -eo pipefail

# ============================================================
# 获取最新 Jetty 版本，更新 Dockerfile，生成 versions.json
# 支持 JDK 和 JRE 变体，根据大版本动态适配 Java 版本
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/template" || { echo "template directory not found"; exit 1; }

# ---------- 配置 ----------
MAJORS=("12.1" "12.0" "10" "9.4")

# 定义每个大版本支持的 Java 版本（JDK 和 JRE）
declare -A SUPPORTED_JAVA_VERSIONS=(
    ["9.4"]="11 17 21 25"
    ["10"]="11 17 21 25"
    ["12.0"]="17 21 25"
    ["12.1"]="17 21 25"
)

# ---------- 日志 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ---------- 错误处理 ----------
die() {
    log "ERROR: $*" >&2
    exit 1
}

# ---------- 根据大版本生成变体列表 ----------
generate_variants() {
    local major="$1"
    local java_versions="${SUPPORTED_JAVA_VERSIONS[$major]}"
    local variants=()
    for java_ver in $java_versions; do
        variants+=("jdk$java_ver" "jdk$java_ver-alpine")
        variants+=("jre$java_ver" "jre$java_ver-alpine")
    done
    echo "${variants[@]}"
}

# ---------- 确保目录存在并创建初始 Dockerfile ----------
ensure_variant_dir() {
    local major="$1"
    local variant="$2"
    local dir="eclipse-temurin/$major/$variant"
    mkdir -p "$dir" || die "Failed to create directory $dir"

    # 提取 Java 版本和类型
    local java_version
    local base_tag
    if [[ "$variant" == jdk* ]]; then
        java_version="${variant#jdk}"
        java_version="${java_version%%-*}"
        base_tag="${java_version}-jdk"
    elif [[ "$variant" == jre* ]]; then
        java_version="${variant#jre}"
        java_version="${java_version%%-*}"
        base_tag="${java_version}-jre"
    else
        die "Unknown variant: $variant"
    fi

    if [[ "$variant" == *-alpine ]]; then
        base_tag="${base_tag}-alpine"
    fi

    cat > "$dir/Dockerfile" <<EOF
FROM eclipse-temurin:$base_tag
EOF
    log "Created initial Dockerfile for $dir with FROM eclipse-temurin:$base_tag"
}

# ---------- 更新所有变体的 Dockerfile ----------
update_all_variants() {
    for major in "${MAJORS[@]}"; do
        variants=($(generate_variants "$major"))
        for variant in "${variants[@]}"; do
            ensure_variant_dir "$major" "$variant"
            log "Updating eclipse-temurin/$major/$variant"
            ./update.sh "eclipse-temurin/$major/$variant" >/dev/null 2>&1 || die "update.sh failed for $major/$variant"
        done
    done
}

# ---------- 修正基础镜像为私有仓库 ----------
fix_base_image_repo() {
    find eclipse-temurin -name "Dockerfile" -exec sed -i 's|^FROM eclipse-temurin:|FROM lcr.loongnix.cn/library/eclipse-temurin:|' {} \;
    log "Fixed base image repository in all Dockerfiles"
}

# ---------- 生成 versions.json ----------
generate_versions_json() {
    local output_file="$SCRIPT_DIR/versions.json"
    rm -f "$output_file"
    echo "{" > "$output_file"
    local first=true
    for major in "${MAJORS[@]}"; do
        local sample_dir="eclipse-temurin/$major/jdk17"
        if [ -f "$sample_dir/Dockerfile" ]; then
            local full_version
            full_version="$(grep "ENV JETTY_VERSION" "$sample_dir/Dockerfile" | awk '{print $3}')"
            if [ -n "$full_version" ]; then
                if [ "$first" = true ]; then
                    first=false
                else
                    echo "," >> "$output_file"
                fi
                echo "  \"$major\": \"$full_version\"" >> "$output_file"
                log "Found $major -> $full_version"
            else
                log "WARNING: Cannot extract version for $major"
            fi
        else
            log "WARNING: $sample_dir/Dockerfile not found"
        fi
    done
    echo "}" >> "$output_file"
    log "Generated $output_file"
}

# ---------- 主函数 ----------
main() {
    # 检查必要命令
    command -v sed >/dev/null 2>&1 || die "sed is required"
    command -v find >/dev/null 2>&1 || die "find is required"
    command -v jq >/dev/null 2>&1 || die "jq is required"

    # 检查 update.sh 是否存在
    [ -x "./update.sh" ] || die "update.sh not found or not executable"

    update_all_variants
    fix_base_image_repo
    generate_versions_json

    log "fetch_versions.sh completed successfully"
}

main "$@"
