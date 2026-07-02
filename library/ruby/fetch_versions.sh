#!/bin/bash
set -eo pipefail

fetch_versions(){
    # 从 ruby/www.ruby-lang.org 获取版本信息
    local versions=$(wget -qO- 'https://github.com/ruby/www.ruby-lang.org/raw/master/_data/releases.yml' | \
        python3 -c "
import sys
import yaml
import re

data = yaml.safe_load(sys.stdin)
versions = []
for release in data:
    version = release.get('version', '')
    # 只获取稳定的 a.b.c 形式版本号
    # 过滤掉包含 preview, rc, alpha, beta, dev, snapshot 等实验性版本
    if re.match(r'^\d+\.\d+\.\d+$', version):
        # 额外过滤掉包含奇怪字符的版本
        if not any(x in version for x in ['-', '+', '~', '^']):
            versions.append(version)
# 去重并排序（按版本号降序）
versions = sorted(set(versions), reverse=True)
for v in versions:
    print(v)
")
    
    echo "$versions" \
        | grep -Fxv -f ignore_versions.txt 2>/dev/null \
        | { grep -Fxv -f processed_versions.txt || [ $? -eq 1 ]; } \
        | head -n 2

}

fetch_versions
