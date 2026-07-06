#!/bin/bash
set -eo pipefail

mkdir -p template

FTP_BASE="https://ftp.loongnix.cn/Java/"
VERSIONS_JSON="template/versions.json"

MAJORS=(8 11 17 21 25 26)

echo '{}' > "$VERSIONS_JSON"

for major in "${MAJORS[@]}"; do
    echo "Processing JDK $major ..." >&2
    
    API_URL="https://api.adoptium.net/v3/assets/feature_releases/${major}/ga?page=0&page_size=1&vendor=eclipse"
    release=$(curl -fsSL "$API_URL" | jq -r '.[0]')
    
    if [ -z "$release" ] || [ "$release" = "null" ]; then
        echo "  No release found for JDK $major" >&2
        continue
    fi
    
    # 从 release_name 获取版本号
    release_name=$(echo "$release" | jq -r '.release_name')
    echo "  release_name: $release_name" >&2
    
    # 提取 Temurin 版本号
    if [[ "$release_name" == jdk8u* ]]; then
        # jdk8u492-b09 -> 8u492-b09
        temurin_version="${release_name#jdk}"
    elif [[ "$release_name" == jdk-* ]]; then
        # jdk-11.0.31+11 -> 11.0.31+11
        temurin_version="${release_name#jdk-}"
    else
        temurin_version=$(echo "$release" | jq -r '.version_data.openjdk_version')
    fi
    echo "  Temurin version: $temurin_version" >&2
    
    # 转换为龙芯文件名中的版本格式
    # JDK 8: 去掉连字符 (8u492-b09 -> 8u492b09)
    # JDK 11+: 将 + 替换为 _ (11.0.31+11 -> 11.0.31_11)
    if [[ "$major" -eq 8 ]]; then
        loongarch_version=$(echo "$temurin_version" | tr -d '-')
    else
        loongarch_version=$(echo "$temurin_version" | tr '+' '_')
    fi
    echo "  LoongArch version: $loongarch_version" >&2
    
    # 在龙芯 FTP 中查找匹配的文件
    FTP_DIR="${FTP_BASE}openjdk${major}/"
    # 使用更宽松的匹配：查找包含 jdk${loongarch_version} 的 glibc2.34 文件
    file=$(curl -sL "$FTP_DIR" | grep -o "loongson[^\"]*glibc2\.34\.tar\.gz" | grep "jdk${loongarch_version}" | head -1 || true)
    
    if [ -z "$file" ]; then
        echo "  No matching file found in $FTP_DIR for version $loongarch_version" >&2
        continue
    fi
    
    download_url="${FTP_DIR}${file}"
    echo "  Found: $download_url" >&2
    
    # 提取龙芯内部版本号（如 8.1.27, 11.18.27）
    internal_version=$(echo "$file" | grep -oP 'loongson\K[0-9.]+')
    
    # 写入 JSON
    jq --arg major "$major" \
       --arg version "$temurin_version" \
       --arg internal "$internal_version" \
       --arg url "$download_url" \
       --arg file "$file" \
       '. + {($major): {
            version: $version,
            internal: $internal,
            url: $url,
            file: $file,
            tarball: {
                jdk: null,
                jre: null
            }
        }}' "$VERSIONS_JSON" > "$VERSIONS_JSON.tmp"
    mv "$VERSIONS_JSON.tmp" "$VERSIONS_JSON"
done

echo "Generated $VERSIONS_JSON"
