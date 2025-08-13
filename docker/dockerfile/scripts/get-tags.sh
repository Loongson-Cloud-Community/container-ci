#!/bin/bash

REPO="moby/buildkit"
PAGE=1
# Use a temporary file to store all raw tags, one per line
# This avoids issues with shell variable size limits or complex string manipulation.
TEMP_TAGS_FILE=$(mktemp)

echo "正在从 GitHub API 获取所有标签..." >&2 # 打印到标准错误，不影响标准输出的JSON

# 循环遍历所有分页以获取所有标签
while true; do
  RESPONSE=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                   -G "https://api.github.com/repos/${REPO}/tags" \
                   --data-urlencode "per_page=100" \
                   --data-urlencode "page=${PAGE}")

  # 检查响应是否为空或只包含空数组，表示没有更多标签了
  if [ "$(echo "$RESPONSE" | jq 'length')" -eq 0 ]; then
    break
  fi

  # 提取当前页的标签名称，直接写入临时文件
  echo "$RESPONSE" | jq -r '.[] | .name' >> "$TEMP_TAGS_FILE"

  PAGE=$((PAGE + 1))

  # 为了避免触发 GitHub API 的速率限制，可以在这里添加一个短暂的延迟
  #sleep 0.1
done

# 从临时文件读取所有标签，过滤并格式化为 JSON 数组
# -R: Read raw strings
# -s: Slurp all input into a single string
# -c: Compact output (ensures no newlines, which is crucial for GITHUB_OUTPUT)
# split("\n"): 将字符串按换行符分割成数组
# map(select(startswith("dockerfile/"))): 过滤出以 "dockerfile/" 开头的元素
# map(select(length > 0)): 移除可能存在的空字符串元素 (例如文件末尾的空行)
#jq -R -s -c 'split("\n") | map(select(startswith("dockerfile/"))) | map(select(length > 0))' "$TEMP_TAGS_FILE"
jq -R -s -c '
  split("\n") |
  map(select(startswith("dockerfile/"))) |
  map(select(length > 0)) |
  # Find the index of the tag we want to stop before
  # and take only the slice up to that index.
  # If "dockerfile/1.4.0-labs" is not found, it will include all matching tags.
  (
    . as $tags |
    reduce range(0; length) as $i (
      {result: [], found: false};
      if $tags[$i] == "dockerfile/1.1.0" then
        .found = true
      elif .found == false then
        .result += [$tags[$i]]
      else
        .
      end
    ) | .result[:60]
  )
' "$TEMP_TAGS_FILE"

# 清理临时文件
rm "$TEMP_TAGS_FILE"
