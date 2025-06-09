#!/usr/bin/env bash
set -Eeuo pipefail

[ -f versions.json ] # run "versions.sh" first

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
	# https://github.com/docker-library/bashbrew/blob/master/scripts/jq-template.awk
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
	rm -rf "$version"

	for variant in debian alpine; do
		export version variant

		dir="$version/$variant"

		echo "processing $dir ..."

		mkdir -p "$dir"

		{
			generated_warning
			gawk -f "$jqt" Dockerfile.template
		} > "$dir/Dockerfile"

		cp -a docker-entrypoint.sh "$dir/"
		cp -a config.guess "$dir/"
		cp -a config.sub "$dir/"
	done
	jinja2 Makefile.template -D tags="${version},${version}-trixie" > "${version}/debian/Makefile"
	jinja2 Makefile.template -D tags="${version}-alpine,${version}-alpine3.21" > "${version}/alpine/Makefile"
done
