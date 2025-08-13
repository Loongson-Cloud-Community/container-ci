# 测试数据（包含 loongarch64 文件名）
test_data="buildx-v0.25.0-linux-loongarch64"

# 使用 jq 解析
echo "$test_data" | jq -R 'capture("[.](?<os>linux|windows|darwin|[a-z0-9]*bsd)-(?<arch>[^.]+)(?<ext>[.]exe)?$")'
