#!/bin/bash

set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

version="$1"
major_ver=$(echo "$version" | cut -d. -f1)
minor_ver=$(echo "$version" | cut -d. -f2)
patch_ver=$(echo "$version" | cut -d. -f3)
ver_num=$(( 10#$major_ver * 1000000 + 10#$minor_ver * 1000 + 10#$patch_ver ))

target_dir="$version"

# 创建目标目录
mkdir -p "$target_dir"

# Dockerfile
tar -xzf $version-src.tar.gz -C $target_dir --strip-components=1

# web
if [ "$ver_num" -ge 1012000 ]; then
    sed -i "/RUN pnpm build/i \\
RUN pnpm build || true \\
RUN chmod +x ./swc-patch.sh && ./swc-patch.sh" "$target_dir/web/Dockerfile"
fi


# api
cp api-dockerfile.template "$target_dir/api/Dockerfile"

echo "[✓] dockerfiles of web and api generated at $target_dir/web and $target_dir/api respectively"

