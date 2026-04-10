#/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <context name>"
    exit 1
fi

context="$1"

echo "patching ..."

##### api #####
api_pyproject=$context/api/pyproject.toml

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
next_ver=$(sed -n 's/.*"next": "\(.*\)".*/\1/p' "$context/web/package.json" | tr -d ', ')

# native binding
wget -O "$context/web/libnext_napi_bindings.so" --quiet --show-progress "https://github.com/loongarch64-releases/next.js/releases/download/v$next_ver/libnext_napi_bindings.so"
chmod +x "$context/web/libnext_napi_bindings.so"

# loongarch swc 的package.json
cat << 'EOF' >> "$context/web/swc-package.json"
{
  "name": "@next/swc-linux-loong64-musl",
  "version": "NEXT_VER",
  "os": ["linux"],
  "cpu": ["loong64"],
  "main": "next-swc.linux-loong64-musl.node"
}
EOF
sed -i "s/NEXT_VER/$next_ver/" "$context/web/swc-package.json"

# 准备 swc 环境
cat << 'EOF' >> "$context/web/swc-patch.sh"
#!/bin/sh
mkdir -p node_modules/@next/swc-linux-loong64-musl
mv ./libnext_napi_bindings.so ./node_modules/@next/swc-linux-loong64-musl/next-swc.linux-loong64-musl.node
mv ./swc-package.json ./node_modules/@next/swc-linux-loong64-musl/package.json
sed -i "/linux.arm64,/a \\
            loong64: \[ \\
                { \\
                    platform: 'linux', \\
                    arch: 'loong64', \\
                    abi: 'musl', \\
                    platformArchABI: 'linux-loong64-musl', \\
                    raw: 'loongarch64-unknown-linux-musl' \\
                } \\
            \]," ./node_modules/next/dist/build/swc/index.js
EOF

echo "done"
