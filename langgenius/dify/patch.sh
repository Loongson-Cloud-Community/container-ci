#/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <context name>"
    exit 1
fi

context="$1"
api_pyproject=$context/api/pyproject.toml

echo "patching ..."

##### api #####
sed -i 's/pandas\[excel,output-formatting,performance\]/pandas\[excel,output-formatting\]/' $api_pyproject
sed -i 's/"intersystems-irispython/#"intersystems-irispython/' $api_pyproject
#sed -i 's/.*pypdfium2.*/    "pypdfium2==4.30.1",/' $api_pyproject
#sed -i 's/.*couchbase.*/    "couchbase==4.3.5",/' $api_pyproject
sed -i '/couchbase/d' $api_pyproject
sed -i '/dependencies = \[/a\
    "python-calamine==0.5.3",' $api_pyproject
#sed -i '/vdb = \[/a\
#    "milvus-lite==2.4.11",' $api_pyproject
sed -i '/vdb = \[/a\
    "onnxruntime==1.23.2",' $api_pyproject
#sed -i '/vdb = \[/a\
#    "pyarrow==22.0.0",' $api_pyproject
sed -i '/\[dependency-groups]/i\
[[tool.uv.index]]\
name = "loongson"\
url = "https://lpypi.loongnix.cn/loongson/pypi/+simple/"\
default = true\
\
[tool.uv.sources]\
onnxruntime = { url = "https://github.com/loong64/onnxruntime/releases/download/v1.23.2/onnxruntime-1.23.2-cp311-cp311-manylinux_2_38_loongarch64.whl" }\
' $api_pyproject
sed -i 's/epub,//' $api_pyproject # 将 pypandoc-binary 替换为 pypandoc
sed -i '/dev = \[/a\
    "pypandoc==1.17",' $api_pyproject
sed -i '/dependencies = \[/a\
    "psycopg-binary==3.2.13",' $api_pyproject

# 更新 uv.lock
pushd $context/api
UV_VERSION=0.8.9
mkdir uv
wget -O uv.tar.gz --quiet --show-progress https://github.com/loong64/uv/releases/download/${UV_VERSION}/uv-loongarch64-unknown-linux-gnu.tar.gz
tar -xzf uv.tar.gz -C uv --strip-components=1
uv/uv python install 3.11
uv/uv lock --refresh --python 3.11
popd

##### web #####
# 使用webpack作为打包器
sed -i 's/next build/next build --webpack/' "$context/web/package.json"
# 补全文件后缀，防止swc-wasm找不到
sed -i "s@'./env'@'./env.ts'@" "$context/web/next.config.ts"
sed -i "s@'./utils/client'@'./utils/client.ts'@" "$context/web/env.ts"
sed -i "s@'./utils/object'@'./utils/object.ts'@" "$context/web/env.ts"

echo "done"
