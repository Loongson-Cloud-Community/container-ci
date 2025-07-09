#!/usr/bin/env bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -x


docker build --platform linux/amd64 -f Dockerfile.build -t lcr.loongnix.cn/library/hello-world:build --push .

find */ \( -name hello -or -name hello.txt \) -delete
docker run --rm lcr.loongnix.cn/library/hello-world:build sh -c 'find \( -name hello -or -name hello.txt -or -name .host-arch \) -print0 | xargs -0 tar --create' | tar --extract --verbose

find -name hello -type f -exec dirname '{}' ';' | xargs -n1 -i'{}' cp Dockerfile-linux.template '{}/Dockerfile'
find -name hello.txt -type f -exec dirname '{}' ';' | xargs -n1 -i'{}' cp Dockerfile-windows.template '{}/Dockerfile'

for h in */*/nanoserver-*/Dockerfile; do
	nano="$(dirname "$h")"
	nano="$(basename "$nano")"
	nano="${nano#nanoserver-}"
	sed -i 's!FROM .*!FROM mcr.microsoft.com/windows/nanoserver:'"$nano"'!' "$h"
done

for h in .host-arch/*/hello; do
	[ -f "$h" ] || continue
	echo "====  $h ===="
	d="$(dirname "$h")"
	b="$(basename "$d")"
	"$h" > /dev/null
	docker build -t hello-world:"test-$b" "$d"
	docker run --rm hello-world:"test-$b"
done

ls -lh */*/{hello,nanoserver*/hello.txt} || :

# 在脚本最后添加以下内容

# 检查并创建 targets 目录（如果不存在）
if [ ! -d "targets" ]; then
    echo "创建 targets 目录..."
    mkdir -p targets
else
    echo "targets 目录已存在，跳过创建"
fi

# 复制各架构的 hello 二进制文件到 targets 目录
echo "开始复制各架构二进制文件..."
for arch_dir in */*/hello; do
    if [ -f "$arch_dir" ]; then  # 确保文件存在
        arch_name=$(dirname "$arch_dir" | cut -d'/' -f1)
        echo "复制 $arch_dir 到 targets/hello-$arch_name"
        cp "$arch_dir" "targets/hello-$arch_name"
        chmod +x "targets/hello-$arch_name"
    fi
done

#复制docker-bake.hcl 到targets目录
if [ -f "docker-bake.hcl" ]; then
    cp "docker-bake.hcl" "targets/docker-bake.hcl"
else
    echo "警告: docker-bake.hcl 文件不存在，无法复制到 targets 目录" >&2
fi

# 复制 Dockerfile 到 targets 目录作为 Dockerfile
if [ -f "Dockerfile" ]; then
    echo "复制 Dockerfile 到 targets/Dockerfile"
    cp "Dockerfile" "targets/Dockerfile"
else
    echo "警告: Dockerfile 文件不存在，无法复制到 targets 目录" >&2
fi

mkdir -p targets/contexts

for arch in amd64 arm32v5 arm32v6 arm32v7 arm64v8 i386 loongarch64 ppc64le riscv64 s390x; do
  mkdir -p "targets/contexts/$arch"
  cp "targets/hello-$arch" "targets/contexts/$arch/hello"
  cp "targets/Dockerfile" "targets/contexts/$arch/Dockerfile"
  rm -f "targets/hello-$arch"
done

rm -f "targets/Dockerfile"
# 显示最终结果
echo "操作完成，targets 目录内容:"
ls -lh targets/ || echo "无法列出 targets 目录内容" >&2
cd targets && docker buildx bake --push  --provenance=false 
#cd targets
cd ../ && rm -rf targets
