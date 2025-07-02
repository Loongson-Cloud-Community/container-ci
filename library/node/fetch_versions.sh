#!/usr/bin/env bash
set -eo pipefail
set -u

readonly ORG='nodejs'
readonly PROJ='node'

declare -a IGNORE_VERSIONS=()

get_github_tags()
{
    local org=$1
    local proj=$2
    curl -s "https://api.github.com/repos/$org/$proj/tags?per_page=100" | jq -r '.[].name'
}

fetch_versions() {
    local majors=(20 22 24)
    local all_versions=()

    local all_tags
    all_tags=$(get_github_tags "$ORG" "$PROJ")

    for m in "${majors[@]}"; do
        local filtered
        filtered=$(echo "$all_tags" | grep -E "^v${m}\." | sort -rV | head -5)

        filtered=$(echo "$filtered" | grep -Fvx -f <(printf "%s\n" "${IGNORE_VERSIONS[@]}") || true)

        if [[ -f versions.txt ]]; then
            filtered=$(echo "$filtered" | grep -Fvx -f versions.txt || true)
        fi

        while read -r v; do
            [[ -z "$v" ]] && continue
            all_versions+=("$v")
        done <<< "$filtered"
    done

    printf '%s\n' "${all_versions[@]}"
}

# 调用函数输出结果
fetch_versions

