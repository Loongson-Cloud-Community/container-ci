#!/bin/bash
set -eo pipefail

# 从 template/versions.json 读取所有主版本号（13,14,15,16）
jq -r 'keys[]' template/versions.json | sort -n
