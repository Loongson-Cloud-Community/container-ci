readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

create_pr() {

	# 1. 创建临时工作目录
	local -r src_dir="$1"
	local -r dst_dir="$2"
	local -r branch="$3"
	local -r wkdir=$(mktemp -d)
	local -r docker_library_url='https://github.com/Loongson-Cloud-Community/docker-library.git'

	# 参数校验
	if [[ -z "$src_dir" || -z "$dst_dir" || -z "$branch" ]]; then
		echo "Usage: create_pr <src_dir> <dst_dir> <branch>"
		return 1
	fi

	# 2. 克隆仓库并创建分支
	pushd "${wkdir}" >/dev/null
	{
		git clone --depth=1 "${docker_library_url}"
		cd docker-library
		git checkout -b "${branch}"
		rm -rf "${dst_dir}"
		mkdir -p "${dst_dir}"
	}
	popd >/dev/null

	# 3. 拷贝 dockerfile 和资源文件
	cp -r "$src_dir/." "$wkdir/docker-library/$dst_dir"

	# 4. 提交并创建 PR
	pushd "${wkdir}/docker-library" >/dev/null
	{
		git config user.name "github-actions[bot]"
		git config user.email "github-actions[bot]@users.noreply.github.com"

		git add "${dst_dir}"
		git commit -m "[auto submmit]: add ${dst_dir}"
		git push origin "${branch}"

		local -r retries=3
		local -r delay=2
		for ((i = 1; i <= retries; i++)); do
			echo "Attempt $i: Creating PR from $src_dir to $dst_dir on branch $branch..."

			gh pr create \
				--title "update: add ${dst_dir}" \
				--body "" \
				--head ${branch} \
				--base main

			if [[ $? -eq 0 ]]; then
				echo "PR created successfully."
				break
			else
				echo "Failed to create PR. Retrying in $delay seconds..."
				sleep "$delay"
			fi

		done
	}
	popd >/dev/null

	echo "PR created for $dst_dir on branch $branch"
}

log() {
	local level="$1"
	shift
	local message="$@"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	case "$level" in
	INFO) color="${GREEN}" ;;
	WARN) color="${YELLOW}" ;;
	ERROR) color="${RED}" ;;
	*) color="${NC}" ;;
	esac

	echo -e "${color}[${timestamp}] [${level}] ${message}${NC}" >&2
}

# 每次只添加一个 version
update_versions_file() {
	local version_file="$1"
	local new_version="$2"
	local tmp_file="${version_file}.tmp"

	# 基本参数检查
	[[ -z "$new_version" ]] && {
		echo "ERROR: Empty version" >&2
		return 1
	}
	[[ -z "$version_file" ]] && {
		echo "ERROR: Missing version file" >&2
		return 1
	}

	# 确保文件存在
	touch "$version_file"

	# 合并并排序版本（去重）
	{
		echo "$new_version"
		cat "$version_file"
	} | sort -Vu >"$tmp_file" || return 1

	# 检查变更并替换文件
	if ! cmp -s "$version_file" "$tmp_file"; then
		mv "$tmp_file" "$version_file" || return 1
		echo "Add ${new_version} into ${version_file}"
	else
		rm -f "$tmp_file"
		echo "No changes"
	fi
}
