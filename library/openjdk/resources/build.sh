#!/bin/bash

set -e

current_dir=$(pwd)
log_file="$current_dir/build.log"

echo "构建日志 - $(date)" > "$log_file"

for dir in */; do
    dir=${dir%/}
    echo "处理目录: $dir" | tee -a "$log_file"
    
    cd "$current_dir/$dir"
    
    if [ -f "Makefile" ]; then
        echo "执行: make image" | tee -a "$log_file"
        make image | tee -a "$log_file"
        
        echo "执行: make push" | tee -a "$log_file"
        make push | tee -a "$log_file"
        
        cd "$current_dir"
    else
        echo "跳过: 没有Makefile" | tee -a "$log_file"
        cd "$current_dir"
    fi
    
    echo "----------------------------------------" | tee -a "$log_file"
done

echo "所有目录处理完成" | tee -a "$log_file"
