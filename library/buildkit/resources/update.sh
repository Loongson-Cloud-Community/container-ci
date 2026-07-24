#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION=$1
TEMPLATE_FILE="Dockerfile-template"
OUTPUT_DIR="$VERSION"
GITHUB_URL="https://raw.githubusercontent.com/moby/buildkit/v$VERSION/Dockerfile"

# 创建版本目录
mkdir -p "$OUTPUT_DIR"

# 下载指定版本的 Dockerfile
echo "Downloading Dockerfile for version $VERSION..."
curl -s -o "$OUTPUT_DIR/original.Dockerfile" "$GITHUB_URL"

# 检查下载是否成功
if [ ! -s "$OUTPUT_DIR/original.Dockerfile" ]; then
  echo "Error: Failed to download Dockerfile for version $VERSION"
  exit 1
fi

# 从原始 Dockerfile 中提取 ARG 变量及其值
declare -A args_map
while read -r line; do
  if [[ $line =~ ^ARG[[:space:]]+([A-Za-z0-9_]+)=(.+) ]]; then
    arg_name="${BASH_REMATCH[1]}"
    arg_value="${BASH_REMATCH[2]}"
    args_map["$arg_name"]="$arg_value"
  fi
done < "$OUTPUT_DIR/original.Dockerfile"

# 处理模板文件
echo "Generating Dockerfile from template..."
cp "$TEMPLATE_FILE" "$OUTPUT_DIR/Dockerfile"

# 注入 BUILDKIT_VERSION（模板需要此变量来 clone 对应版本的源码，替换所有 stage 内的声明）
sed -i "s/^ARG BUILDKIT_VERSION$/ARG BUILDKIT_VERSION=$VERSION/g" "$OUTPUT_DIR/Dockerfile"

# 替换模板中的 ARG 变量（跳过 BUILDKIT_VERSION，已单独处理）
for arg_name in "${!args_map[@]}"; do
  [[ "$arg_name" == "BUILDKIT_VERSION" ]] && continue
  arg_value="${args_map[$arg_name]}"
  if sed --version 2>&1 | grep -q GNU; then
    sed -i "s/^ARG[[:space:]]*$arg_name\\(=.*\\)\\{0,1\\}$/ARG $arg_name=$arg_value/" "$OUTPUT_DIR/Dockerfile"
  else
    sed -i "" "s/^ARG[[:space:]]*$arg_name\\(=.*\\)\\{0,1\\}$/ARG $arg_name=$arg_value/" "$OUTPUT_DIR/Dockerfile"
  fi
done

echo "Successfully generated Dockerfile in $OUTPUT_DIR/"
