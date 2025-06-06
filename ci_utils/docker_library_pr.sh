#!/bin/bash
set -eo pipefail

REPO="Loongson-Cloud-Community/docker-library"
AUTHOR="qiangxuhui"

get_mergeable_prs() {
    gh pr list --repo "$REPO" --state open --json number,title,author,mergeable | jq -r '
        map(
            select(.author.login == "'"$AUTHOR"'" and .mergeable == "MERGEABLE")
            | .number
        ) | .[]
    '
}

merge_prs() {
    local prs=("$@")
    if [ ${#prs[@]} -eq 0 ]; then
        echo "No mergeable PRs found."
        return
    fi

    for pr_number in "${prs[@]}"; do
        echo "Merging PR #$pr_number..."
        gh pr merge "$pr_number" --merge --delete-branch --repo "$REPO"
    done
}

main() {
    mergeable_prs=($(get_mergeable_prs))
    merge_prs "${mergeable_prs[@]}"
}

main
