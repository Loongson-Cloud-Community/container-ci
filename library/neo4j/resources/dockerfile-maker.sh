#!/bin/bash

set -euo pipefail

VERSION="$1"
MAJOR_VER="$(echo "$VERSION" | cut -d. -f1)"

CONTEXT=$VERSION

if [ "$MAJOR_VER" == 5 ]; then
    __JDK_VER__=21
else
    __JDK_VER__=11
fi
__NEO4J_TARBALL__="neo4j-community-$VERSION-SNAPSHOT-unix.tar.gz"
__NEO4J_EDITION__=community
__NEO4J_URI__="https://github.com/loongarch64-releases/neo4j/releases/download/$VERSION/$__NEO4J_TARBALL__"

cp Dockerfile.template "$CONTEXT/Dockerfile"
sed -i "s|__JDK_VER__|$__JDK_VER__|" "$CONTEXT/Dockerfile"
sed -i "s|__NEO4J_TARBALL__|$__NEO4J_TARBALL__|" "$CONTEXT/Dockerfile"
sed -i "s|__NEO4J_EDITION__|$__NEO4J_EDITION__|" "$CONTEXT/Dockerfile"
sed -i "s|__NEO4J_URI__|$__NEO4J_URI__|" "$CONTEXT/Dockerfile"
