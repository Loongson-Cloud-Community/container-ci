#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly REGISTRY='lcr.loongnix.cn'
readonly ORG='prometheus-operator'
readonly PROJ='prometheus-operator'

# Prepare $version
prepare()
{

    local version="$1"
    log INFO "Preparing version $version"


    pushd template > /dev/null || {
        log ERROR "Failed to enter template directory: $SOURCES_DIR"
        exit 1
    }

    ./apply-templates.sh "$version" || {
        log ERROR "${template_dir}/apply-templates.sh script failed for version: $version"
        exit 1
    }

    popd
}


process()
{
    local version=$1
    prepare $version
}

process $1

