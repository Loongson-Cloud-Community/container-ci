#!/bin/bash
set -eo pipefail

# 获取最新版本号
latest_version=$(curl -fsSL https://api.github.com/repos/postfixadmin/postfixadmin/releases/latest | jq -r '.tag_name' | sed 's/^v//')
if [ -z "$latest_version" ]; then
    echo "ERROR: Failed to fetch latest version" >&2
    exit 1
fi
echo "Latest version: $latest_version"

# 下载对应的 tarball 并计算 SHA512
tarball_url="https://github.com/postfixadmin/postfixadmin/archive/v${latest_version}.tar.gz"
tarball_file="/tmp/postfixadmin-${latest_version}.tar.gz"
curl -fsSL -o "$tarball_file" "$tarball_url"
sha512=$(sha512sum "$tarball_file" | cut -d' ' -f1)
rm "$tarball_file"

echo "SHA512: $sha512"

mkdir -p template
cat > template/versions.json <<EOF
{
  "$latest_version": {
    "version": "$latest_version",
    "sha512": "$sha512",
    "variants": ["apache", "fpm", "fpm-alpine"]
  }
}
EOF

echo "Generated template/versions.json"
