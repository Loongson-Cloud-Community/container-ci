#!/usr/bin/env bash
set -ue

function usage() {
  cat << EOF
Usage:
  $0 <full_version> [variant]

Example:
  $0 v20.19.2 alpine3.21
  $0 v20.19.3 trixie
  $0 v20.19.3 trixie-slim
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

full_version="$1"     # 例如 v20.19.2
variant="${2:-}"      # 例如 alpine3.21 或 debian-trixie，没传默认空

# 去掉v，方便目录命名
ver_dir="${full_version#v}"  # 20.19.2

base_resources_dir="resources"

# 模板路径（顶层统一放模板）
function get_template_path() {
  local var="$1"
  case "$var" in
    alpine* )
      echo "Dockerfile-alpine.template"
      ;;
    trixie )
      echo "Dockerfile-debian.template"
      ;;
    trixie-slim* )
      echo "Dockerfile-slim.template"
      ;;
    "" )
      echo "Dockerfile.template"
      ;;
    * )
      echo "Dockerfile.template"
      ;;
  esac
}

# 构造目标目录
target_dir="${ver_dir}"
if [ -n "$variant" ]; then
  target_dir="${target_dir}/${variant}"
fi

mkdir -p "$target_dir"

template_path=$(get_template_path "$variant")
dockerfile_path="${target_dir}/Dockerfile"

echo "Using template: $template_path"
echo "Generating Dockerfile: $dockerfile_path"

echo "当前目录: $(pwd)"
cp "$template_path" "${dockerfile_path}.tmp"

# 替换 NODE_VERSION
sed -i -E "s/^(ENV NODE_VERSION ).*/\1${full_version#v}/" "${dockerfile_path}.tmp"

# 替换 ALPINE_VERSION
# 假设 variant=alpine3.21
nodeVersion=${ver_dir}
if [[ "$variant" =~ alpine([0-9]+\.[0-9]+) ]]; then
  alpine_version="${BASH_REMATCH[1]}"
  sed -i -E "s|^FROM alpine:0\.0|FROM alpine:${alpine_version}|" "${dockerfile_path}.tmp"
  if [ "$(uname -m)" = "loongarch64" ]; then
	echo "url=== https://github.com/yzewei/node/releases/download/v${nodeVersion}/node-v${nodeVersion}-linux-loong64-musl.tar.xz.sha256"
        checksum=$(
            curl -sSL --compressed "https://github.com/yzewei/node/releases/download/v${nodeVersion}/node-v${nodeVersion}-linux-loong64-musl.tar.xz.sha256" | cut -d' ' -f1
        )
	echo "la checksum=${checksum}"
      else
        checksum=$(
            curl -sSL --compressed "https://unofficial-builds.nodejs.org/download/release/v${nodeVersion}/SHASUMS256.txt" \
            | grep "node-v${nodeVersion}-linux-x64-musl.tar.xz" \
            | cut -d' ' -f1
        )
  fi
  if [ -z "$checksum" ]; then
        rm -f "${dockerfile_path}.tmp"
        fatal "Failed to fetch checksum for version ${nodeVersion}"
      fi
  sed -Ei -e "s/CHECKSUM=CHECKSUM_x64/CHECKSUM=\"${checksum}\"/" "${dockerfile_path}.tmp"
  sed -Ei -e "s/CHECKSUM=CHECKSUM_loong64/CHECKSUM=\"${checksum}\"/" "${dockerfile_path}.tmp"
  echo "echo ========${checksum}"
elif [[ "$variant" == trixie ]]; then
  debian_version="trixie"
  sed -i -E "s|^FROM buildpack-deps:name|FROM buildpack-deps:${debian_version}|" "${dockerfile_path}.tmp"
elif [[ "$variant" == trixie-slim ]]; then
  debian_version="trixie-slim"
  sed -i -E "s|^FROM debian:name-slim|FROM debian:${debian_version}|" "${dockerfile_path}.tmp"
fi

# 如果是 alpine 并且 loongarch64 架构，替换 ARCH
if [[ "$(uname -m)" == "loongarch64" ]]; then
  echo "Setting ARCH=loong64 for loongarch64 on Alpine"
  sed -i -E "s|RUN ARCH=.?[a-z0-9]*|RUN ARCH=loong64 |" "${dockerfile_path}.tmp"
fi

#yarnVersion="$(curl -sSL --compressed https://yarnpkg.com/latest-version)"
#yarnVersion="$(curl -sSL https://registry.npmmirror.com/yarn/latest | jq -r .version)"
VERSION_FILE="yarnversion"

# 判断是否存在，且在1小时内修改过
if [ -f "$VERSION_FILE" ] && [ "$(find "$VERSION_FILE" -mmin -60)" ]; then
  echo "✅ 使用缓存版本: $(cat "$VERSION_FILE")"
else
  echo "🔄 正在获取最新 yarn 版本..."
  curl -sSL https://registry.npmmirror.com/yarn/latest | jq -r .version > "$VERSION_FILE"
  echo "✅ 已更新版本: $(cat "$VERSION_FILE")"
fi
yarnVersion=$(cat "$VERSION_FILE")
sed -Ei -e 's/^(ENV YARN_VERSION ).*/\1'"${yarnVersion}"'/' "${dockerfile_path}.tmp"

./update-keys.sh
new_line=' \\\
'

for key_type in node yarn; do
  pattern="\\\"\\\$\\{$(echo "${key_type}" | tr '[:lower:]' '[:upper:]')_KEYS\\[@\\]\\}\\\""

  while IFS= read -r line; do
    # 替换内容里的反斜杠要加四个反斜杠表示字面 \\
    escaped_line=$(printf '%s' "$line" | sed 's/\\/\\\\\\\\/g')
    sed -Ei "s|([[:space:]]*)(${pattern})|\\1${escaped_line}${new_line}\\1\\2|" "${dockerfile_path}.tmp"
  done < "keys/${key_type}.keys"

#  echo "替换内容： $escaped_line"
  sed -Ei "/${pattern}/d" "${dockerfile_path}.tmp"
done

mv "${dockerfile_path}.tmp" "$dockerfile_path"

# 复制 docker-entrypoint.sh 到目标目录
if [ -f "docker-entrypoint.sh" ]; then
  cp "docker-entrypoint.sh" "$target_dir/"
fi

echo "✅ Dockerfile and entrypoint prepared in $target_dir"
