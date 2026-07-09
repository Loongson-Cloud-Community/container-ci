#!/bin/bash
set -eo pipefail

# ============================================================
# 获取最新 Temurin 版本，生成 versions.json
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FTP_BASE="https://ftp.loongnix.cn/Java/"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"

# ---------- 日志 ----------
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# ---------- 错误处理 ----------
die() {
    log "ERROR: $*" >&2
    exit 1
}

# ---------- 检查依赖 ----------
check_dependencies() {
    command -v curl >/dev/null 2>&1 || die "curl is required"
    command -v jq >/dev/null 2>&1 || die "jq is required"
}

# ---------- 从 API 获取 Temurin 版本号 ----------
fetch_temurin_version() {
    local major="$1"
    local api_url="https://api.adoptium.net/v3/assets/feature_releases/${major}/ga?page=0&page_size=1&vendor=eclipse"
    local release
    release="$(curl -fsSL "$api_url" | jq -r '.[0]')"
    if [ -z "$release" ] || [ "$release" = "null" ]; then
        echo ""
        return 1
    fi
    local release_name
    release_name="$(echo "$release" | jq -r '.release_name')"
    local temurin_version
    if [[ "$release_name" == jdk8u* ]]; then
        temurin_version="${release_name#jdk}"
    elif [[ "$release_name" == jdk-* ]]; then
        temurin_version="${release_name#jdk-}"
    else
        temurin_version="$(echo "$release" | jq -r '.version_data.openjdk_version')"
    fi
    echo "$temurin_version"
}

# ---------- 转换为龙芯文件名中的版本格式 ----------
to_loongarch_version() {
    local major="$1"
    local temurin_version="$2"
    if [[ "$major" -eq 8 ]]; then
        echo "$temurin_version" | tr -d '-'
    else
        echo "$temurin_version" | tr '+' '_'
    fi
}

# ---------- 在龙芯 FTP 查找匹配的 tarball ----------
find_loongarch_tarball() {
    local major="$1"
    local loongarch_version="$2"
    local ftp_dir="${FTP_BASE}openjdk${major}/"
    local file
    file="$(curl -sL "$ftp_dir" | grep -o "loongson[^\"]*glibc2\.34\.tar\.gz" | grep "jdk${loongarch_version}" | head -1 || true)"
    if [ -z "$file" ]; then
        echo ""
        return 1
    fi
    echo "${ftp_dir}${file}"
}

# ---------- 主函数 ----------
main() {
    check_dependencies

    mkdir -p template
    echo '{}' > "$VERSIONS_JSON"

    local majors=(8 11 17 21 25)
    for major in "${majors[@]}"; do
        log "Processing JDK $major ..."
        local temurin_version
        temurin_version="$(fetch_temurin_version "$major")"
        if [ -z "$temurin_version" ]; then
            log "  No release found for JDK $major"
            continue
        fi
        log "  Temurin version: $temurin_version"

        local loongarch_version
        loongarch_version="$(to_loongarch_version "$major" "$temurin_version")"
        log "  LoongArch version: $loongarch_version"

        local download_url
        download_url="$(find_loongarch_tarball "$major" "$loongarch_version")"
        if [ -z "$download_url" ]; then
            log "  No matching file found in FTP for version $loongarch_version"
            continue
        fi
        log "  Found: $download_url"

        local file_name="${download_url##*/}"
        local internal_version
        internal_version="$(echo "$file_name" | grep -oP 'loongson\K[0-9.]+')"

        # 写入 JSON
        jq --arg major "$major" \
           --arg version "$temurin_version" \
           --arg internal "$internal_version" \
           --arg url "$download_url" \
           --arg file "$file_name" \
           '. + {($major): {
                version: $version,
                internal: $internal,
                url: $url,
                file: $file,
                tarball: {
                    jdk: null,
                    jre: null
                }
            }}' "$VERSIONS_JSON" > "${VERSIONS_JSON}.tmp" || die "jq failed"
        mv "${VERSIONS_JSON}.tmp" "$VERSIONS_JSON"
    done

    log "Generated $VERSIONS_JSON"
}

main "$@"
