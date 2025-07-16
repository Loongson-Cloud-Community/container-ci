#!/bin/bash
set -eo pipefail

if ceho "123"; then 
   echo "succ"
else
   echo "fail"
fi
