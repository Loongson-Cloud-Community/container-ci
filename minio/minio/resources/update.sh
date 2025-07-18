#!/usr/bin/env bash
set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <minio_version>"
    exit 1
fi

minio_version="$1"
target_dir="$minio_version"
template_file="Dockerfile.template"

# 创建目标目录
mkdir -p "$target_dir"

echo "[*] Fetching mc version from minio image: $minio_version..."

# 提取 mc 版本（例如 RELEASE.2025-06-13T11-33-47Z）
mc_version=$(docker run --rm --entrypoint=/bin/bash --platform linux/amd64 "quay.io/minio/minio:$minio_version" -c "mc --version" 2>/dev/null \
    | grep -o 'RELEASE\.[0-9T:-]*Z' \
    | head -n1)

docker rmi -f quay.io/minio/minio:$minio_version

if [ -z "$mc_version" ]; then
    echo "[!] Failed to detect mc version from minio:$minio_version"
    exit 2
fi

echo "[*] Detected mc version: $mc_version"

# 渲染模板
awk -v minio_version="$minio_version" -v mc_version="$mc_version" '
{
    gsub(/{{[[:space:]]*minio_version[[:space:]]*}}/, minio_version);
    gsub(/{{[[:space:]]*mc_version[[:space:]]*}}/, mc_version);
    print;
}
' "$template_file" > "$target_dir/Dockerfile"

echo "[✓] Dockerfile generated at: $target_dir/Dockerfile"

