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
    # 公共模块（所有 Java 11+ 版本共有）
    BASE_MODULES="java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml,java.xml.crypto,jdk.accessibility,jdk.charsets,jdk.crypto.cryptoki,jdk.dynalink,jdk.httpserver,jdk.jdwp.agent,jdk.jfr,jdk.jsobject,jdk.localedata,jdk.management,jdk.management.jfr,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.sctp,jdk.security.auth,jdk.security.jgss,jdk.unsupported,jdk.zipfs"

    # 各版本特有模块
    MODULES_11_SPECIFIC="jdk.aot,jdk.internal.ed,jdk.internal.le,jdk.internal.vm.compiler,jdk.internal.vm.compiler.management,jdk.management.agent,jdk.naming.ldap,jdk.pack,jdk.scripting.nashorn,jdk.scripting.nashorn.shell"
    MODULES_17_SPECIFIC="jdk.incubator.foreign,jdk.incubator.vector,jdk.nio.mapmode"
    MODULES_21_SPECIFIC="jdk.incubator.vector,jdk.nio.mapmode"
    MODULES_25_SPECIFIC="jdk.graal.compiler,jdk.graal.compiler.management,jdk.incubator.vector,jdk.nio.mapmode"

    case "$MAJOR" in
        11)
            JRE_MODULES="${BASE_MODULES},${MODULES_11_SPECIFIC}"
            ;;
        17)
            JRE_MODULES="${BASE_MODULES},${MODULES_17_SPECIFIC}"
            ;;
        21)
            JRE_MODULES="${BASE_MODULES},${MODULES_21_SPECIFIC}"
            ;;
        25)
            JRE_MODULES="${BASE_MODULES},${MODULES_25_SPECIFIC}"
            ;;
        *)
            echo "不支持的 Java 版本: $MAJOR" >&2
            exit 1
            ;;
    esac

    # 过滤实际存在的模块
    get_existing_modules() {
        local modules_list="$1"
        local jmods_dir="$JDK_TARGET_DIR/jmods"
        local existing_modules=""
        IFS=',' read -ra mod_array <<< "$modules_list"
        for mod in "${mod_array[@]}"; do
            if [ -f "$jmods_dir/$mod.jmod" ]; then
                if [ -z "$existing_modules" ]; then
                    existing_modules="$mod"
                else
                    existing_modules="$existing_modules,$mod"
                fi
            else
                echo "警告: 模块 $mod 不存在，已跳过" >&2
            fi
        done
        echo "$existing_modules"
    }

    JRE_MODULES_EXISTING=$(get_existing_modules "$JRE_MODULES")
    if [ -z "$JRE_MODULES_EXISTING" ]; then
        echo "错误: 没有可用的 JRE 模块" >&2
        exit 1
    fi

    rm -rf "$WORK_DIR/jre-loongarch"
    "$JDK_TARGET_DIR/bin/jlink" \
        --module-path "$JDK_TARGET_DIR/jmods" \
        --add-modules "$JRE_MODULES_EXISTING" \
        --output "$WORK_DIR/jre-loongarch"
#        --compress=2
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
