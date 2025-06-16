#!/bin/bash
set -eo pipefail

versions=$(cat versions.json | jq -rc 'keys | .[]')

for version in $versions; do

	# 1.创建目录
	rm -rf $version
	mkdir $version

	# 2.拷贝Dockerfile
	cp Dockerfile "$version/"

	# 3.生成makefile
	jq <versions.json \
		-cr \
		--arg version $version \
		' .[$version]' | \
	jinja2 Makefile.template - > "$version/Makefile"
done
