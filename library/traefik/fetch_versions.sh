#!/bin/bash
set -eo pipefail

REPO_URL="https://api.github.com/repos/traefik/traefik/releases/latest"

fetch_version() {
    curl -fsSL "$REPO_URL" | jq -r '.tag_name' | sed 's/^v//'
}

fetch_version
