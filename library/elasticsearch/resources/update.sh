#!/bin/bash

set -Eeuo pipefail

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

version="$1"
major_ver=$(echo "$version" | cut -d. -f1)

target_dir="$version"
template_file="Dockerfile.template"

# 创建目标目录
mkdir -p "$target_dir"

# 渲染模板
awk -v version="$version" '
{
    gsub(/{{[[:space:]]*version[[:space:]]*}}/, version);
    print;
}
' "$template_file" > "$target_dir/Dockerfile"
if [ "$major_ver" -ge 9 ]; then
    sed -i "/elasticsearch.yml/d" "$target_dir/Dockerfile"
    sed -i "/log4j2.docker.properties/d" "$target_dir/Dockerfile"
    sed -i 's|find config -type f -exec chmod 0664 {} +|& \&\& \\|' "$target_dir/Dockerfile"
    sed -i "/find config -type f -exec chmod 0664 {} +/a \\
    chmod 0775 . \&\& chown 1000:1000 bin config config\/jvm.options.d data logs plugins \\
COPY --chmod=664 config\/elasticsearch.yml config\/log4j2.properties config\/" "$target_dir/Dockerfile"
    sed -i "s/unzip zip passwd tini/& findutils procps/" "$target_dir/Dockerfile"
    sed -i "/ENV PATH \/usr\/share\/elasticsearch\/bin:\$PATH/i\\
RUN ln -sf \/etc\/pki\/ca-trust\/extracted\/java\/cacerts jdk\/lib\/security\/cacerts" "$target_dir/Dockerfile"
    sed -i "/COPY bin\/docker-openjdk \/etc\/ca-certificates\/update.d\/docker-openjdk/d" "$target_dir/Dockerfile"
    sed -i "/RUN \/etc\/ca-certificates\/update.d\/docker-openjdk/d" "$target_dir/Dockerfile"
fi

echo "[✓] Dockerfile generated at: $target_dir/Dockerfile"
