#!/bin/bash

set -Eeuo pipefail

VERSION="$1"
CLEAN_VER="${VERSION#v}" && CLEAN_VER="${CLEAN_VER#e}"
MAJOR_VER="$(echo "$CLEAN_VER" | cut -d. -f1)"
MINOR_VER="$(echo "$CLEAN_VER" | cut -d. -f2)"
VER_NUM="$(( 10#$MAJOR_VER * 1000 + 10#$MINOR_VER ))"
if [ "${VER_NUM}" -ge 5009 ]; then
    EMQX_NAME=emqx-enterprise
else
    EMQX_NAME=emqx
fi

ID=debian
VERSION_ID=13
EMQX_VERSION="$CLEAN_VER"
CONTEXT="$VERSION"

SHA256=$(curl -sSL https://github.com/loongarch64-releases/emqx/releases/download/${VERSION}/${EMQX_NAME}-${EMQX_VERSION}-${ID}-loongarch64.tar.gz.sha256 | awk '{print $1}')

cp Dockerfile.template "$CONTEXT/Dockerfile"

sed -i "s/ARG RAW_VERSION=/&$VERSION/" "$CONTEXT/Dockerfile"

sed -i "s/ARG EMQX_NAME=/&$EMQX_NAME/" "$CONTEXT/Dockerfile"

sed -i "s/ARG ID=/&$ID/" "$CONTEXT/Dockerfile"

sed -i "s/ARG VERSION_ID=/&$VERSION_ID/" "$CONTEXT/Dockerfile"

sed -i "s/ENV EMQX_VERSION=/&$EMQX_VERSION/" "$CONTEXT/Dockerfile"

sed -i "s/ENV LOONG64_SHA256=/&$SHA256/" "$CONTEXT/Dockerfile"

