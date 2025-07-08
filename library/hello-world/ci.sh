#!/bin/bash

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly ORG='library'
readonly PROJ='hello-world'
main()
{
    log INFO "Process build"
    ./process_build.sh

}

main "$@"
