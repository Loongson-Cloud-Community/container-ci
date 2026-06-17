#!/bin/bash
set -eo pipefail

REPO_URL="https://github.com/znc/znc.git"

fetch_latest_version() {
    git ls-remote --tags "$REPO_URL" \
        | grep -oE 'refs/tags/znc-[0-9]+\.[0-9]+\.[0-9]+$' \
        | sed 's|refs/tags/znc-||' \
        | sort -V \
        | tail -1
}

fetch_latest_version
