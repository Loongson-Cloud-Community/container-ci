#/bin/bash

version="$1"
context=$version

major_ver=$(echo "$version" | cut -d. -f1)
minor_ver=$(echo "$version" | cut -d. -f2)
patch_ver=$(echo "$version" | cut -d. -f3)
ver_num=$(( 10#$major_ver * 1000000 + 10#$minor_ver * 1000 + 10#$patch_ver ))

patch_api()
{
    local api_pyproject=$context/api/pyproject.toml

    sed -i 's/pandas\[excel,output-formatting,performance\]/pandas\[excel,output-formatting\]/' $api_pyproject
    sed -i 's/"intersystems-irispython/#"intersystems-irispython/' $api_pyproject
    #sed -i 's/.*pypdfium2.*/    "pypdfium2==4.30.1",/' $api_pyproject
    sed -i 's/.*couchbase.*/    "couchbase==4.3.5",/' $api_pyproject
    sed -i '/couchbase/d' $api_pyproject
    sed -i '/dependencies = \[/a\
    "python-calamine==0.5.3",' $api_pyproject
    #sed -i '/vdb = \[/a\
#    "milvus-lite==2.4.11",' $api_pyproject
    sed -i '/dependencies = \[/a\
    "onnxruntime==1.23.2",' $api_pyproject
    #sed -i '/vdb = \[/a\
#    "pyarrow==22.0.0",' $api_pyproject
    sed -i '/\[dependency-groups]/i\
[[tool.uv.index]]\
name = "loongson"\
url = "https://lpypi.loongnix.cn/loongson/pypi/+simple/"\
default = true\
[[tool.uv.index]]\
name = "standby"\
url = "https://pypi.org/simple"\
explicit = true' $api_pyproject
    sed -i '/\[tool.uv]/a\
environments = [\
    "sys_platform == '\''linux'\''"\
]' $api_pyproject

    if [ "$ver_num" -ge 1013001 ]; then
	if [ "$ver_num" -lt 1014000 ]; then
            sed -i 's/epub,//' $api_pyproject # 将 pypandoc-binary 替换为 pypandoc
            sed -i '/dev = \[/a\
    "pypandoc~=1.17",' $api_pyproject
	fi
        sed -i '/dependencies = \[/a\
    "psycopg-binary==3.2.13",' $api_pyproject
    fi

    if [ "$ver_num" -lt 1014000 ]; then
       sed -i '/\[dependency-groups\]/i\
[tool.uv.sources]\
onnxruntime = { url = "https://github.com/loong64/onnxruntime/releases/download/v1.23.2/onnxruntime-1.23.2-cp312-cp312-manylinux_2_38_loongarch64.whl" }\
' $api_pyproject
    else
	sed -i '/\[tool.uv.sources\]/a\
onnxruntime = { url = "https://github.com/loong64/onnxruntime/releases/download/v1.23.2/onnxruntime-1.23.2-cp312-cp312-manylinux_2_38_loongarch64.whl" }\
litellm = { index = "standby" }' $api_pyproject # 构建1.14.1时阿里源的litellm最新版本没有与上游同步
        sed -i '/dify-vdb-iris/s/^/#/' $api_pyproject
	sed -i '/dependencies = \[/a\
"unstructured[docx,md,ppt,pptx]~=0.21.5",' $api_pyproject
    fi

}

# 更新 uv.lock
update_uv_lock()
{
    pushd $context/api

    UV_VERSION=0.8.9
    mkdir uv
    wget -O uv.tar.gz --quiet --show-progress "https://github.com/loong64/uv/releases/download/${UV_VERSION}/uv-loongarch64-unknown-linux-gnu.tar.gz"
    tar -xzf uv.tar.gz -C uv --strip-components=1
    uv/uv python install 3.12

    MAX_RETRIES=5
    UV_LOCK_COUNT=0
    UV_LOCK_SUCCESS=false

    # 重复多次以处理网络波动
    until [ $UV_LOCK_COUNT -ge $MAX_RETRIES ] || [ "$UV_LOCK_SUCCESS" = true ]; do
	echo "Attempting uv lock ($((COUNT+1))/$MAX_RETRIES)..."
	if UV_HTTP_TIMEOUT=1200 UV_HTTP_RETRIES=10 uv/uv lock --python 3.12; then
            UV_LOCK_SUCCESS=true
            echo "uv lock successful!"
        else
	    UV_LOCK_COUNT=$((UV_LOCK_COUNT+1))
            echo "uv lock failed, retrying..."
            sleep 1
	fi
    done

    if [ "$UV_LOCK_SUCCESS" = false ]; then
        echo "Error: Failed to update uv.lock after $MAX_RETRIES attempts."
        exit 1
    fi

    popd
}

patch_web()
{
    # 启用 swc 构建和 turbopack 打包
    if [ "$ver_num" -ge 1012000 ]; then
        enable_swc
    fi

    # tailwindcss 4+ 依赖原生绑定
    if [ "$ver_num" -ge 1014000 ]; then
        adapt_tailwindcss_v4
    fi
}

adapt_tailwindcss_v4()
{
    # 需要 libtailwind_oxide.so 和 liblightningcss_node.so
    # 前者负责 Tailwind v4 的类名扫描与核心提取，后者负责 CSS 的最终编译与压缩
    local lightningcss_ver=$(sed -n 's/^[[:space:]]*lightningcss@\([0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p' "$context/pnpm-lock.yaml" | head -n 1)
    local tailwindcss_ver=$(sed -n 's/^[[:space:]]*tailwindcss@\([0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p' "$context/pnpm-lock.yaml" | head -n 1)

    wget -O "$context/web/liblightningcss_node.so" --quiet --show-progress "https://github.com/loongarch64-releases/lightningcss/releases/download/v$lightningcss_ver/liblightningcss_node.so"
    wget -O "$context/web/libtailwind_oxide.so" --quiet --show-progress "https://github.com/loongarch64-releases/tailwindcss/releases/download/v$tailwindcss_ver/libtailwind_oxide.so"

    cat << 'EOF' > "$context/web/css-patch.sh"
#!/bin/sh
LIGHTNINGCSS_DIR=$(find ../node_modules/.pnpm -name "lightningcss" -type d | grep "node_modules/lightningcss$" | head -n 1)
TAILWIND_DIR=$(find ../node_modules/.pnpm -name "oxide" -type d | grep "node_modules/@tailwindcss/oxide$" | head -n 1)
mv ./liblightningcss_node.so "$LIGHTNINGCSS_DIR/lightningcss.linux-loong64-musl.node"
mv ./libtailwind_oxide.so "$TAILWIND_DIR/tailwindcss-oxide.linux-loong64-musl.node"
EOF
    chmod +x "$context/web/css-patch.sh"
}

enable_swc()
{
    if [ "$ver_num" -lt 1014000 ]; then
        local next_ver=$(sed -n 's/.*"next": "\(.*\)".*/\1/p' "$context/web/package.json" | tr -d ', ')
    else
        local next_ver=$(sed -n 's/^[[:space:]]*next:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$context/pnpm-workspace.yaml")
    fi

    # 启用 swc 所需的胶水文件
    wget -O "$context/web/libnext_napi_bindings.so" --quiet --show-progress "https://github.com/loongarch64-releases/next.js/releases/download/v$next_ver/libnext_napi_bindings.so"
    chmod +x "$context/web/libnext_napi_bindings.so"

     # loongarch swc 的package.json
    cat << 'EOF' > "$context/web/swc-package.json"
{
  "name": "@next/swc-linux-loong64-musl",
  "version": "NEXT_VER",
  "os": ["linux"],
  "cpu": ["loong64"],
  "main": "next-swc.linux-loong64-musl.node"
}
EOF
    sed -i "s/NEXT_VER/$next_ver/" "$context/web/swc-package.json"

    # 构建 swc 模块环境
    if [ "$ver_num" -ge 1014000 ]; then
	node_modules_base=".."
    else
	node_modules_base="."
    fi
    cat << 'EOF' > "$context/web/swc-patch.sh"
#!/bin/sh
mkdir -p NODE_MODULES_BASE/node_modules/@next/swc-linux-loong64-musl
mv ./libnext_napi_bindings.so NODE_MODULES_BASE/node_modules/@next/swc-linux-loong64-musl/next-swc.linux-loong64-musl.node
mv ./swc-package.json NODE_MODULES_BASE/node_modules/@next/swc-linux-loong64-musl/package.json
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
    sed -i "s/NODE_MODULES_BASE/$node_modules_base/" "$context/web/swc-patch.sh"

    chmod +x "$context/web/swc-patch.sh"
}

patch()
{
    echo "patching ..."

    patch_api
    update_uv_lock
    patch_web

    echo "done"
}

patch
