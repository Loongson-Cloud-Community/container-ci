#!/bin/bash

dockerfile="$1"

sed -i 's#FROM alpine.*#FROM lcr.loongnix.cn/library/alpine:latest#' "$dockerfile"

sed -i '/LPM_SHA256/d' "$dockerfile"

sed -i '/case "$arch" in/a\
      loongarch64)   DOWNLOAD_ARCH="-loong64"  ;; \\' "$dockerfile"

sed -i 's#github.com/liquibase/liquibase-package-manager#github.com/loongarch64-releases/liquibase-package-manager#' "$dockerfile"
