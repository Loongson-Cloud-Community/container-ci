#!/bin/bash
set -eo pipefail

versions=$(jq<versions.json -rc 'keys | .[]')
for version in ${versions};do

	for os_type in alpine debian;do
		data=$(jq<versions.json -rc --arg version "$version" '.[$version]')
		dir_="$version/$os_type"
		mkdir -p "${dir_}"
		echo $data | jinja2 Dockerfile-${os_type}.template - > "$dir_/Dockerfile"
		cp docker-entrypoint.sh ${dir_}/
	done
    jinja2 Makefile.template -D tags="${version}-alpine,${version}-alpine3.21" > "${version}/alpine/Makefile"
	jinja2 Makefile.template -D tags="${version},${version}-trixie" > "${version}/debian/Makefile"
done

