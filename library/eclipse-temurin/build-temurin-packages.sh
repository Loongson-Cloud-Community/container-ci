#!/bin/bash
set -eu

# 用法: ./build-temurin-packages.sh <major_version>
# 示例: ./build-temurin-packages.sh 8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_JSON="${SCRIPT_DIR}/template/versions.json"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp}"

MAJOR="${1:-}"

if [ -z "$MAJOR" ]; then
    echo "用法: $0 <major_version>"
    exit 1
fi

if [ ! -f "$VERSIONS_JSON" ]; then
    echo "错误: 找不到 $VERSIONS_JSON，请先运行 fetch_versions.sh" >&2
    exit 1
fi

echo "Using versions.json: $VERSIONS_JSON"

# 从 versions.json 读取该大版本的信息
TEMURIN_VERSION=$(jq -r ".\"$MAJOR\".version" "$VERSIONS_JSON")
URL=$(jq -r ".\"$MAJOR\".url" "$VERSIONS_JSON")
FILE=$(jq -r ".\"$MAJOR\".file" "$VERSIONS_JSON")

if [ -z "$TEMURIN_VERSION" ] || [ -z "$URL" ]; then
    echo "错误: 版本 $MAJOR 在 $VERSIONS_JSON 中缺少必要字段" >&2
    exit 1
fi

echo "Building JDK $MAJOR ($TEMURIN_VERSION) from $FILE"

# 转换为 tarball 文件名中的版本格式
if [[ "$MAJOR" -eq 8 ]]; then
    TARBALL_VERSION=$(echo "$TEMURIN_VERSION" | tr -d '-')
else
    TARBALL_VERSION=$(echo "$TEMURIN_VERSION" | tr '+' '_')
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "下载 LoongArch JDK ..."
wget -v -O "$WORK_DIR/jdk-loongarch.tar.gz" "$URL" || {
    echo "错误: 下载失败" >&2
    exit 1
}

# 解压 JDK
mkdir -p "$WORK_DIR/jdk-loongarch"
tar -xzf "$WORK_DIR/jdk-loongarch.tar.gz" -C "$WORK_DIR/jdk-loongarch" --strip-components=1

# ---- 打包 JDK ----
JDK_TARGET_DIR="$WORK_DIR/jdk-${TEMURIN_VERSION}"
mv "$WORK_DIR/jdk-loongarch" "$JDK_TARGET_DIR"

JDK_TAR="OpenJDK${MAJOR}U-jdk_loongarch64_linux_hotspot_${TARBALL_VERSION}.tar.gz"
cd "$WORK_DIR"
tar -czf "$OUTPUT_DIR/$JDK_TAR" "jdk-${TEMURIN_VERSION}"

echo "JDK 打包完成: $OUTPUT_DIR/$JDK_TAR"

# ---- 处理 JRE ----
if [ "$MAJOR" -eq 8 ]; then
    if [ -d "$JDK_TARGET_DIR/jre" ]; then
        JRE_SRC="$JDK_TARGET_DIR/jre"
    else
        echo "错误: JDK 8 中未找到 jre 目录" >&2
        exit 1
    fi
else
    # 使用 jlink 生成 JRE（模块列表可从 x86 获取，这里简化）
    JRE_MODULES="java.base,java.datatransfer,java.desktop,java.logging,java.management,java.naming,java.prefs,java.security.sasl,java.sql,java.transaction.xa,java.xml,jdk.unsupported"
    rm -rf "$WORK_DIR/jre-loongarch"
    "$JDK_TARGET_DIR/bin/jlink" \
        --module-path "$JDK_TARGET_DIR/jmods" \
        --add-modules "$JRE_MODULES" \
        --output "$WORK_DIR/jre-loongarch" \
        --compress=2
    JRE_SRC="$WORK_DIR/jre-loongarch"
fi

JRE_TARGET_DIR="$WORK_DIR/jre-${TEMURIN_VERSION}"
mv "$JRE_SRC" "$JRE_TARGET_DIR"

JRE_TAR="OpenJDK${MAJOR}U-jre_loongarch64_linux_hotspot_${TARBALL_VERSION}.tar.gz"
cd "$WORK_DIR"
tar -czf "$OUTPUT_DIR/$JRE_TAR" "jre-${TEMURIN_VERSION}"

echo "JRE 打包完成: $OUTPUT_DIR/$JRE_TAR"

# ---- 回写 tarball 文件名到 versions.json ----
echo "Updating $VERSIONS_JSON with tarball names..."
if ! jq --arg major "$MAJOR" \
      --arg jdk_tar "$JDK_TAR" \
      --arg jre_tar "$JRE_TAR" \
      '.[$major].tarball.jdk = $jdk_tar | .[$major].tarball.jre = $jre_tar' \
      "$VERSIONS_JSON" > "${VERSIONS_JSON}.tmp"; then
    echo "ERROR: jq command failed" >&2
    exit 1
fi
mv "${VERSIONS_JSON}.tmp" "$VERSIONS_JSON"
echo "已更新 $VERSIONS_JSON"
