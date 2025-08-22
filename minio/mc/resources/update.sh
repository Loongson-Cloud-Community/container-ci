#!/usr/bin/env bash
set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <mc_version>"
    exit 1
fi

mc_version="$1"
target_dir="$mc_version"
template_file="Dockerfile.template"

# 创建目标目录
mkdir -p "$target_dir"

# 渲染模板
awk -v mc_version="$mc_version" ' 
{
    gsub(/{{[[:space:]]*mc_version[[:space:]]*}}/, mc_version);
    print;
}
' "$template_file" > "$target_dir/Dockerfile"

echo "[✓] Dockerfile generated at: $target_dir/Dockerfile"

