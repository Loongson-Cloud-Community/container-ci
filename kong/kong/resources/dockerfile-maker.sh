#!/bin/bash

set -Eeuo pipefail

version="$1"
context=$version

cp Dockerfile.template "$context/Dockerfile"
sed -i "s/__KONG_VERSION__/$version/" "$context/Dockerfile"
