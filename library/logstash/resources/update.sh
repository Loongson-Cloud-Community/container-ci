#!/bin/bash

set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

version="$1"
target_dir="$version"
templates=("Dockerfile.template.1" "Dockerfile.template.2")
dockerfiles=("dockerfile-1" "dockerfile-2")

# 创建目标目录
mkdir -p "$target_dir"

# 渲染模板
for i in "${!templates[@]}"; do
	template="${templates[$i]}"
	dockerfile="${dockerfiles[$i]}"

	awk -v version="${version#v}" '
	{
		gsub(/{{[[:space:]]*version[[:space:]]*}}/, version);
		print;
	}
	' "$template" > "$target_dir/$dockerfile"
done

echo "[✓] Dockerfiles generated at: $target_dir"
