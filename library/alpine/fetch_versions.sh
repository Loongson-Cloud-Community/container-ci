#!/bin/bash
set -eo pipefail

readonly FTP_BASE='https://cz.alpinelinux.org/alpine'

fetch_versions(){

     local versions=$(wget -qO- https://cz.alpinelinux.org/alpine/latest-stable/releases/loongarch64 \
        | grep -oP 'minirootfs-\K[\d\.]+(?=-loongarch64\.tar\.gz)' \
        | sort -V \
        | uniq)


    echo "$versions" \
        | sort -V \
        | grep -Fxv -f processed_versions.txt \
        | { grep -Fxv -f ignore_versions.txt || [ $? -eq 1 ]; }
}


fetch_versions
