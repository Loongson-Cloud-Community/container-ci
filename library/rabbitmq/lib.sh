readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case "$level" in
        INFO) color="${GREEN}";;
        WARN) color="${YELLOW}";;
        ERROR) color="${RED}";;
        *) color="${NC}";;
    esac

    echo -e "${color}[${timestamp}] [${level}] ${message}${NC}" >&2
}

update_versions_file() {
    local version_file="$1"
    local new_versions="$2"
    local tmp_file="${version_file}.tmp"

    # 基本参数检查
    [[ -z "$new_versions" ]] && { echo "ERROR: Empty versions" >&2; return 1; }
    [[ -z "$version_file" ]] && { echo "ERROR: Missing version file" >&2; return 1; }

    # 确保文件存在
    touch "$version_file"

    # 合并并排序版本（去重）
    {
        echo "$new_versions" | tr ' ' '\n'
        cat "$version_file"
    } | sort -Vu > "$tmp_file" || return 1

    # 检查变更并替换文件
    if ! cmp -s "$version_file" "$tmp_file"; then
        mv "$tmp_file" "$version_file" || return 1
        echo "Updated $version_file ($(wc -l < "$version_file") versions)"
    else
        rm -f "$tmp_file"
        echo "No changes"
    fi
}

# upload_release $org $proj $version $file
upload_release()
{
    if [ $# -ne 4 ]; then
        echo "Error: Exactly 4 arguements required, but got $#"
        return 1
    fi
    local org="$1"
    local proj="$2"
    local version="$3"
    local file="$4"
    curl -F file=@$file http://cloud.loongnix.xa/releases/loongarch64/"$1"/"$2"/"$3"
}

git_commit() 
{
    local org="$1"
    local proj="$2"
    local versions="$3"
    git add versions.txt resources

    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    echo "$ORG $PROJ: add versions ${versions[@]}"
    git commit -m "$ORG $PROJ: add versions ${versions[@]}"
    git pull --rebase
    git push origin main
}
