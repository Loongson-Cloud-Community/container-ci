#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly ORG='library'
readonly PROJ='hello-world'
main()
{
    log INFO "Process build"
    ./process_build.sh

    # 4. 提交仓库
    git_commit "$ORG" "$PROJ" "update hello-world build"

}

main "$@"
