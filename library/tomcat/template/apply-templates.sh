#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# 根据 versions.json 和 Dockerfile.template 生成所有 Dockerfile
# ============================================================

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
[ -f versions.json ] || { echo "versions.json not found"; exit 1; }

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
    jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ ! -f "$jqt" ]; then
    wget -qO "$jqt" 'https://github.com/docker-library/bashbrew/raw/9f6a35772ac863a0241f147c820354e4008edf38/scripts/jq-template.awk'
fi

if [ "$#" -eq 0 ]; then
    versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
    eval "set -- $versions"
fi

generated_warning() {
    cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

for version; do
    export version
    variants="$(jq -r '.[env.version].variants | map(@sh) | join(" ")' versions.json)"
    eval "variants=( $variants )"

    rm -rf "$version/"
    for variant in "${variants[@]}"; do
        export variant   # 关键：供 from.jq 使用
        dir="$version/$variant"
        mkdir -p "$dir"
        echo "processing $dir ..."
        {
            generated_warning
            gawk -f "$jqt" Dockerfile.template
        } > "$dir/Dockerfile"
    done
done
