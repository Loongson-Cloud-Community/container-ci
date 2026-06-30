#!/bin/bash

set -euo pipefail

version="$1"
context=$version

major_ver=$(echo ${version} | cut -d. -f1)
minor_ver=$(echo ${version} | cut -d. -f2)
ver_num=$(( 10#$major_ver * 1000 + 10#$minor_ver ))

cp Dockerfile.template "$context/Dockerfile"

if [  "${ver_num}" -ge 1007 ]; then
    sed -i 's#apk del .build-deps#& \&\& \\#' "$context/Dockerfile"
    sed -i '/apk del .build-deps/a \
    addgroup -S kapacitor && \\\
    adduser -S kapacitor -G kapacitor && \\\
    mkdir -m 0750 -p /var/lib/kapacitor && \\\
    chown kapacitor:kapacitor /var/lib/kapacitor' "$context/Dockerfile"
fi

if [  "${ver_num}" -ge 1008 ]; then
    sed -i 's/su-exec/setpriv/' "$context/Dockerfile"
fi

sed -i "s/__APACITOR_VER__/${version}/" "$context/Dockerfile"
