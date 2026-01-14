#/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <context name>"
    exit 1
fi

context="$1"
api_pyproject=$context/api/pyproject.toml

echo "patching ..."

sed -i 's/pandas\[excel,output-formatting,performance\]/pandas\[excel,output-formatting\]/' $api_pyproject
sed -i 's/"intersystems-irispython/#"intersystems-irispython/' $api_pyproject
sed -i 's/.*pypdfium2.*/    "pypdfium2==4.30.1",/' $api_pyproject
sed -i 's/.*couchbase.*/    "couchbase==4.3.5",/' $api_pyproject
sed -i '/dependencies = \[/a\
    "python-calamine==0.5.3",' $api_pyproject
sed -i '/vdb = \[/a\
    "milvus-lite==2.4.11",' $api_pyproject
sed -i '/vdb = \[/a\
    "onnxruntime==1.23.2",' $api_pyproject
sed -i '/vdb = \[/a\
    "pyarrow==22.0.0",' $api_pyproject
sed -i '/\[dependency-groups]/i\
[[tool.uv.index]]\
name = "loongson"\
url = "https://lpypi.loongnix.cn/loongson/pypi/+simple/"\
default = true\
\
[tool.uv.sources]\
onnxruntime = { url = "https://github.com/loong64/onnxruntime/releases/download/v1.23.2/onnxruntime-1.23.2-cp312-cp312-manylinux_2_38_loongarch64.whl" }\
' $api_pyproject

# 更新 uv.lock
pushd $context/api
UV_VERSION=0.8.9
mkdir uv
wget -O uv.tar.gz --quiet --show-progress https://github.com/loong64/uv/releases/download/${UV_VERSION}/uv-loongarch64-unknown-linux-gnu.tar.gz
tar -xzf uv.tar.gz -C uv --strip-components=1
uv/uv python install 3.12
uv/uv lock --refresh --python 3.12
popd

echo "done"
