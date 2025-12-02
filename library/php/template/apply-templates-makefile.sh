#!/bin/bash
set -eo pipefail

gen_tags() {
	# 获取 dockerfile 的路径
	local -r dockerfile=$1

	# 获取 dockerfile 所在的目录路径
	local -r dir_apth=$(dirname "$dockerfile")

	# 使用 '/' 分割目录，将结果保存在数组 parts 中
	IFS='/' read -r -a parts <<<"$dir_apth"

	# 简单校验：确保路径中至少包含两个层级（如 version/os）
	if [[ ${#parts[@]} -lt 2 ]]; then
		echo "Invalid path: $dockerfile" >&2
		return 1
	fi

	# 提取数组倒数第二项为版本号（version），倒数第一项为操作系统（os）
	local -r version=${parts[-3]}
	local -r os=${parts[-2]}
	local -r feature=${parts[-1]}

	# 拼接出标签
	if [[ $os = 'trixie' ]]; then
		echo "${version}-${feature}-${os},${version}-${feature}"
		return
	fi
	echo "${version}-${feature}-${os}"
}

main() {
    local version="$1"
	local -r dockerfiles=$(find ./$version -name 'Dockerfile')
	for dockerfile in $dockerfiles:; do
		tags=$(gen_tags $dockerfile)
		dir_path=$(dirname "$dockerfile")
		jinja2 Makefile.template -D tags=$tags >"$dir_path/Makefile"
	done
}

main "$1"
