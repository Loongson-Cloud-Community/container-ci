#!/bin/bash

set -euo pipefail

version="$1"
context=$version

major_ver=$(echo ${version} | cut -d. -f1)
minor_ver=$(echo ${version} | cut -d. -f2)

if [ "$major_ver" -eq 3 ]; then
	cp Dockerfile.v3 "$context/Dockerfile"
	sed -i "s/__INFLUXDB_VER__/$version/" "$context/Dockerfile"

elif [ "$major_ver" -eq 2 ]; then
    dasel_ver=$(curl -fsSL "https://raw.githubusercontent.com/influxdata/influxdata-docker/master/influxdb/${version%.*}/alpine/Dockerfile" \
        | sed -n 's#.*TomWright/dasel/releases/download/\(v[^/]*\)/.*#\1#p' \
        | head -n 1)
    influx_cli_ver=$(curl -fsSL "https://raw.githubusercontent.com/influxdata/influxdata-docker/master/influxdb/${version%.*}/alpine/Dockerfile" \
        | sed -n 's/^[[:space:]]*ENV[[:space:]]\+INFLUX_CLI_VERSION[[:space:]=]\+\([^[:space:]]\+\).*/\1/p' \
        | head -n 1)

    cp Dockerfile.v2 "$context/Dockerfile"
    sed -i "s/__INFLUXDB_VER__/$version/" "$context/Dockerfile"
    sed -i "s/__DASEL_VER__/$dasel_ver/" "$context/Dockerfile"
    sed -i "s/__INFLUX_CLI_VER__/$influx_cli_ver/" "$context/Dockerfile"
    if [ "${minor_ver}" -le 8 ]; then
	sed -i 's/setpriv/su-exec/' "$context/Dockerfile"
    fi

elif [ "$major_ver" -eq 1 ]; then
    cp Dockerfile.v1 "$context/Dockerfile"
    sed -i "s/__INFLUXDB_VER__/$version/" "$context/Dockerfile"
fi


