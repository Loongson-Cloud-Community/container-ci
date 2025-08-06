#!/usr/bin/env bash
set -Eeuo pipefail
#debug
#set -x

# 参数检查
if [ $# -ne 1 ]; then
    echo "Usage: update.sh <version>"
    exit 1
fi

readonly version=${1#v}
readonly ALPINE_VERSION='3.22'
readonly TEMPLATE_FILE='Dockerfile.template'


generate_dockerfile()
{
    local template_file="$1"
    local target_file="$2"

    gawk -v version="$version" -v alpine_version="$ALPINE_VERSION" '
    {
        gsub(/{{[[:space:]]*\.version[[:space:]]*}}/, version);
        gsub(/{{[[:space:]]*\.alpine\.version[[:space:]]*}}/, alpine_version);
        print
    }
    ' "$TEMPLATE_FILE" > "$target_file"
}

mkdir -p "$version/alpine"
generate_dockerfile "$TEMPLATE_FILE" "$version/alpine/Dockerfile"
cp entrypoint.sh config-example.yml "$version/alpine/"
