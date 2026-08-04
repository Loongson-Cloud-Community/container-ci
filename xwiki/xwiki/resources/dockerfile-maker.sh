#!/bin/bash

set -Eeuo pipefail

version="$1"
context="$2"

major_ver=$(echo "$version" | cut -d. -f1)
dockerfile="$context/Dockerfile"

if [ "$major_ver" -eq 16 ]; then
    tomcat_ver=9.0
else
    tomcat_ver=10.1
fi
sed -i "s#FROM tomcat.*#FROM lcr.loongnix.cn/library/tomcat:$tomcat_ver-jre21#" "$dockerfile"

sed -i '/apt-get --no-install-recommends -y install/a\
    libreoffice \\\
    fontconfig \\\
    fonts-dejavu \\' "$dockerfile"

sed -i '/LIBREOFFICE_VERSION/,/rm -rf \/tmp\/libreoffice/d' "$dockerfile"

sed -i "s/XWIKI_VERSION=.*/XWIKI_VERSION=\"$version\"/" "$dockerfile"

sed -i '/XWIKI_DOWNLOAD_SHA256/d' "$dockerfile"
