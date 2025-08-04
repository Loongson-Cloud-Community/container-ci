#!/usr/bin/env bash
set -Eeuo pipefail

[ -f versions.json ] # run "versions.sh" first

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
	# https://github.com/docker-library/bashbrew/blob/master/scripts/jq-template.awk
        if [ ! -f $jqt ]; then
	    wget -qO "$jqt" 'https://github.com/docker-library/bashbrew/raw/9f6a35772ac863a0241f147c820354e4008edf38/scripts/jq-template.awk'
        fi
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

	if [ -d "$version" ]; then
		rm -rf "$version"
	fi

	if jq -e '.[env.version] | not' versions.json > /dev/null; then
		echo "skipping $version ..."
		continue
	fi

	for variant in alpine debian; do
		export variant

		echo "processing $version/$variant ..."

		mkdir -p "$version/$variant"

		{
			generated_warning
			gawk -f "$jqt" "$variant/Dockerfile.template"
		} > "$version/$variant/Dockerfile"

		cp -f $variant/entrypoint.sh "$version/$variant/"

	done
done
