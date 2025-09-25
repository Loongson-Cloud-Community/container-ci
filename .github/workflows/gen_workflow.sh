#!/usr/bin/bash
# usage: gen_workflow.sh organization repository

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <org> <repo>"
  exit 1
fi

ORG="$1"
REPO="$2"
OUTPUTFILE="$ORG-$REPO.yml"

CRON='0 20 * * *'
TEMPLATE='workflow.tpl'

awk -v org="$ORG" -v repo="$REPO" -v cron="$CRON" '
{
    gsub(/\{\{[[:space:]]*\.org[[:space:]]*\}\}/, org);
    gsub(/\{\{[[:space:]]*\.repo[[:space:]]*\}\}/, repo);
    gsub(/\{\{[[:space:]]*\.cron[[:space:]]*\}\}/, cron);
    print;
}
' "$TEMPLATE" > "$OUTPUTFILE"

echo "Generated: $OUTPUTFILE"
