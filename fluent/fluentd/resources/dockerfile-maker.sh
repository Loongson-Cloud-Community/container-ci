#!/bin/bash

set -euo pipefail

VERSION="$1"
MAJOR_VER=$(echo "$VERSION" | cut -d. -f1)
MINOR_VER=$(echo "$VERSION" | cut -d. -f2)
CONTEXT=$VERSION

RUBY_MAJOR_VER=$(sed -n 's/FROM ruby:\([0-9]\+\)\..*/\1/p' "$CONTEXT/Dockerfile")

sed -i "s#FROM ruby:.*#FROM lcr.loongnix.cn/library/ruby:$RUBY_MAJOR_VER-slim#" "$CONTEXT/Dockerfile"
sed -i '/buildDeps=/a\
      libssl-dev pkg-config \\' "$CONTEXT/Dockerfile"
TEMP_VER=$(sed -n 's/.*Version="\([0-9]\+\.[0-9]\+\.[0-9]\+\)".*/\1/p' "$CONTEXT/Dockerfile" | head -n 1)
sed -i "s/$TEMP_VER/$VERSION/" "$CONTEXT/Dockerfile"

if [ "$MAJOR_VER" -eq 1 ] && [ "$MINOR_VER" -le 16 ]; then
    sed -i 's/ca-certificates/& tini/' "$CONTEXT/Dockerfile"
    sed -i '/dpkgArch=/,/tini -h/d' "$CONTEXT/Dockerfile"
    sed -i '/TINI_VERSION/d' "$CONTEXT/Dockerfile"
fi
