#!/bin/bash

set -Eeuo pipefail

PROJ='openresty'

version="$1"
major_ver=$(echo "$version" | cut -d. -f1)
minor_ver=$(echo "$version" | cut -d. -f2)

context="$version"

if [ "$major_ver" -eq 1 ] && [ "$minor_ver" -le 25 ]; then
    sed -i 's/ARG RESTY_PCRE_BUILD_OPTIONS=.*/ARG RESTY_PCRE_BUILD_OPTIONS=""/' "$context/Dockerfile"
    sed -i '/RESTY_PCRE_SHA256/d' "$context/Dockerfile"
    sed -i '/cd \/tmp\/pcre-${RESTY_PCRE_VERSION}/a \
    && rm -f config.guess config.sub \\\
    && curl -fSL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD" -o config.guess \\\
    && curl -fSL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD" -o config.sub \\' "$context/Dockerfile"

fi 

sed -i 's/ARG RESTY_IMAGE_TAG=.*/ARG RESTY_IMAGE_TAG="3"/' "$context/Dockerfile"
sed -i '/curl -fSL https:\/\/openresty.org\/download\//a \
    && curl -fSL https://github.com/loongarch64-sources/openresty/releases/download/v${RESTY_VERSION}/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \\' "$context/Dockerfile"
sed -i '/curl -fSL https:\/\/openresty.org\/download\//d' "$context/Dockerfile"

# fat
sed -i "s/ARG RESTY_FAT_IMAGE_BASE=.*/ARG RESTY_FAT_IMAGE_BASE=$PROJ/" "$context/Dockerfile.fat"
sed -i "s/ARG RESTY_FAT_IMAGE_TAG=.*/ARG RESTY_FAT_IMAGE_TAG=$version-alpine/" "$context/Dockerfile.fat"
