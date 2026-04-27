#!/usr/bin/env bash
set -Eeuo pipefail

[ -f versions.json ] # run "versions.sh" first

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
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

	major="$(jq -r '.[env.version].major' versions.json)"

	variants="$(jq -r '.[env.version].variants | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	rm -rf "$version"

	for variant in "${variants[@]}"; do
		export variant

		dir="$version/$variant"
		mkdir -p "$dir"

		echo "processing $dir ..."

		case "$variant" in
			alpine*) template='Dockerfile-alpine.template' ;;
			*)       template='Dockerfile-debian.template' ;;
		esac

		{
			generated_warning
			gawk -f "$jqt" "$template"
		} > "$dir/Dockerfile"
		
		# 从 versions.json 中提取完整版本号（如 15.17）
		fullVersion="$(jq -r '.[env.version].version' versions.json)"
		# 生成 Makefile，同时打上完整版号标签和主版本号标签
		{
			printf '.PHONY: image\n'
			printf 'image:\n'
			printf '\tdocker build -t lcr.loongnix.cn/library/postgres:%s-%s -t lcr.loongnix.cn/library/postgres:%s-%s .\n' \
				"$fullVersion" "$variant" "$version" "$variant"
			printf '\n'
			printf '.PHONY: push\n'
			printf 'push:\n'
			printf '\tdocker push lcr.loongnix.cn/library/postgres:%s-%s\n' "$fullVersion" "$variant"
			printf '\tdocker push lcr.loongnix.cn/library/postgres:%s-%s\n' "$version" "$variant"
		} > "$dir/Makefile"
		cp -a docker-entrypoint.sh docker-ensure-initdb.sh "$dir/"
	done
done
