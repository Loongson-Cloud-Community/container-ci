#!/bin/bash

set -Eeuo pipefail

version="$1"
major_ver=$(echo "$version" | cut -d. -f1)
minor_ver=$(echo "$version" | cut -d. -f2)
patch_ver=$(echo "$version" | cut -d. -f3)
ver_num=$(( 10#$major_ver * 1000000 + 10#$minor_ver * 1000 + 10#$patch_ver ))

target_dir="$version"

# web
dockerfile_web()
{
    sed -i -E 's#^(FROM[[:space:]]+node:)([0-9]+)(\.[0-9]+)*-alpine([0-9.]+)?#\1\2-alpine3.23#' "$target_dir/web/Dockerfile"

    if [ "$ver_num" -ge 1012000 ]; then
        sed -i "/RUN pnpm build/i \\
RUN pnpm build || true \\
RUN chmod +x swc-patch.sh css-patch.sh \\
RUN ./swc-patch.sh && ./css-patch.sh" "$target_dir/web/Dockerfile"
    fi

    if [ "$ver_num" -ge 1014000 ]; then # 取消nextjs和vinext双轨构建，仅用 nextjs
        sed -i "s/RUN pnpm build \&\& pnpm build:vinext/RUN pnpm build/" "$target_dir/web/Dockerfile"
        sed -i "s/ENV EXPERIMENTAL_ENABLE_VINEXT=true/ENV EXPERIMENTAL_ENABLE_VINEXT=false/" "$target_dir/web/Dockerfile"
        sed -i "/vinext/d" "$target_dir/web/Dockerfile"
        sed -i "s/pnpm install --frozen-lockfile/& --ignore-scripts/" "$target_dir/web/Dockerfile"
    fi

    if [ "$ver_num" -ge 1015000 ]; then # 配合 patch 对 package.json 的调整
	sed -i '/pnpm install --frozen-lockfile/i \
RUN pnpm install --lockfile-only' "$target_dir/web/Dockerfile"
    fi
}

# api
dockerfile_api()
{
    cp api-dockerfile.template "$target_dir/api/Dockerfile"
    if [ "$ver_num" -ge 1015000 ]; then
        sed -i 's#COPY pyproject.toml uv.lock ./#COPY api/pyproject.toml api/uv.lock ./#' "$target_dir/api/Dockerfile"
        sed -i 's#COPY providers ./providers#COPY api/providers ./providers#' "$target_dir/api/Dockerfile"
        sed -i 's#COPY --chown=dify:dify . /app/api/#COPY --chown=dify:dify api /app/api/#' "$target_dir/api/Dockerfile"
        sed -i 's#docker/entrypoint.sh#api/docker/entrypoint.sh#' "$target_dir/api/Dockerfile"
        sed -i '/COPY api\/providers .\/providers/a \
COPY dify-agent/pyproject.toml dify-agent/README.md /app/dify-agent/ \
COPY dify-agent/src /app/dify-agent/src' "$target_dir/api/Dockerfile"
    fi
}

make_dockerfile()
{
    mkdir -p "$target_dir"
    tar -xzf $version-src.tar.gz -C $target_dir --strip-components=1

    dockerfile_web
    dockerfile_api
}

make_dockerfile
