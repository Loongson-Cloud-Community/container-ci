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
  if [[ $line =~ ^ARG[[:space:]]+([A-Za-z0-9_]+)=([^[:space:]]+) ]]; then
    arg_name="${BASH_REMATCH[1]}"
    arg_value="${BASH_REMATCH[2]}"
    args_map["$arg_name"]="$arg_value"
  fi
done < "$OUTPUT_DIR/original.Dockerfile"

# 处理模板文件
echo "Generating Dockerfile from template..."
cp "$TEMPLATE_FILE" "$OUTPUT_DIR/Dockerfile"

# 替换模板中的 ARG 变量
for arg_name in "${!args_map[@]}"; do
  arg_value="${args_map[$arg_name]}"
  # 在 macOS 上需要使用 -i '' 而不是 -i
  if sed --version 2>&1 | grep -q GNU; then
    sed -i "s/^ARG[[:space:]]*$arg_name\$/ARG $arg_name=$arg_value/" "$OUTPUT_DIR/Dockerfile"
  else
    sed -i "" "s/^ARG[[:space:]]*$arg_name\$/ARG $arg_name=$arg_value/" "$OUTPUT_DIR/Dockerfile"
  fi
done

git clone --depth 1 -b v$VERSION https://github.com/moby/buildkit &&  \
find buildkit/ -mindepth 1 -maxdepth 1 -not -name "Dockerfile" -exec cp -r {} "$OUTPUT_DIR/" \;

echo "Successfully generated Dockerfile in $OUTPUT_DIR/"
rm -rf buildkit
