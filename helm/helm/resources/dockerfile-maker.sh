#!/bin/bash

version="$1"
context="$version"

sed -i "s/ARG VERSION.*/ARG VERSION=$version/" "$context/Dockerfile"
sed -i '/aarch64) ARCH=arm64/a\
        loongarch64) ARCH=loong64; ;; \\' "$context/Dockerfile"
