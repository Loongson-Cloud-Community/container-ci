import re
import os
import sys

def modify_dockerfile(dockerfile_content):
    """
    修改 Dockerfile 内容：
    1. 在第一行前面添加 '#'。
    2. 将 XX_VERSION 的值修改为 '1.6.1'。
    3. 将 ALPINE_VERSION 的值设置为空。
    4. 根据不同的 'AS' 值修改 'FROM' 语句。

    Args:
        dockerfile_content (str): 原始 Dockerfile 的内容。

    Returns:
        str: 修改后的 Dockerfile 内容。
    """
    lines = dockerfile_content.splitlines()
    modified_lines = []

    # 1. 在第一行前面添加 '#'
    if lines:
        modified_lines.append(f"#{lines[0]}")
        remaining_lines = lines[1:]
    else:
        remaining_lines = []

    # 定义用于匹配 golang:1.1X-alpine 的正则表达式
    golang_alpine_pattern = re.compile(r"^(FROM\s+(?:--platform=\$[A-Z_]+\s+)?golang:1\.1\d-alpine)", re.IGNORECASE)
    golang_debian_pattern = re.compile(r"^(FROM\s+(?:--platform=\$[A-Z_]+\s+)?golang:1\.1\d-buster)", re.IGNORECASE)
    golang_default_pattern = re.compile(
        r"^(FROM\s+--platform=\$[A-Z_]+\s+golang:1\.1\d\s+AS\s+base\s*$)",
        re.IGNORECASE
    )
    # Golang patterns with dynamic 'AS'
    golang_xx_pattern = re.compile(r"^(FROM\s+(?:--platform=\$[A-Z_]+\s+)?tonistiigi/xx:golang\S*\s+AS\s+(\S+))", re.IGNORECASE)
    golang_xx_master_pattern = re.compile(r"^(FROM\s+(?:--platform=\$[A-Z_]+\s+)?tonistiigi/xx:master\S*\s+AS\s+(\S+))", re.IGNORECASE)

    # 遍历剩余行进行其他修改
    for line in remaining_lines:
        # 2. 将 XX_VERSION 的值修改为 '1.6.1'
        if line.startswith("ARG XX_VERSION="):
            modified_lines.append("ARG XX_VERSION=1.6.1")
        elif golang_xx_pattern.match(line):
            # 提取 AS 后面的内容（xgo 或 xx）
            match = golang_xx_pattern.match(line)
            as_value = match.group(2).lower()  # 获取 'xgo' 或 'xx'（不区分大小写）
            if as_value == "xgo":
                modified_lines.append("FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.6.1 AS xgo")
            else:
                modified_lines.append("FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.6.1 AS xx")
        elif golang_xx_master_pattern.match(line):
            # 提取 AS 后面的内容（xgo 或 xx）
            match = golang_xx_master_pattern.match(line)
            as_value = match.group(2).lower()  # 获取 'xgo' 或 'xx'（不区分大小写）
            if as_value == "xgo":
                modified_lines.append("FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.6.1 AS xgo")
            else:
                modified_lines.append("FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.6.1 AS xx")
        # 3. 将 ALPINE_VERSION 的值设置为空
        elif line.startswith("ARG ALPINE_VERSION="):
            modified_lines.append("ARG ALPINE_VERSION=")
        # 4. 替换 golang:1.1X-alpine
        elif golang_alpine_pattern.match(line):
            modified_lines.append("FROM --platform=$BUILDPLATFORM golang:1.19-alpine AS base")
        # 5. 替换 golang:1.1X-sid
        elif golang_debian_pattern.match(line):
            modified_lines.append("FROM --platform=$BUILDPLATFORM golang:1.21 AS base")
        elif golang_default_pattern.match(line):
            modified_lines.append("FROM --platform=$BUILDPLATFORM golang:1.21 AS base")
        else:
            modified_lines.append(line)

    return "\n".join(modified_lines)

# 主执行部分
if __name__ == "__main__":
    # 检查命令行参数
    if len(sys.argv) < 2:
        print("用法: python modify_dockerfile.py <Dockerfile路径>")
        print("示例: python modify_dockerfile.py ./Dockerfile")
        sys.exit(1)  # 退出程序，表示错误

    dockerfile_path = sys.argv[1]  # 获取第一个命令行参数作为 Dockerfile 路径

    if not os.path.exists(dockerfile_path):
        print(f"错误: 文件 '{dockerfile_path}' 不存在。")
        sys.exit(1)
    else:
        try:
            with open(dockerfile_path, 'r', encoding='utf-8') as f:
                dockerfile_input = f.read()

            modified_content = modify_dockerfile(dockerfile_input)

            # 直接打印修改后的内容到标准输出
            print(modified_content)

            # 用户可以通过重定向来保存输出，例如：
            # python modify_dockerfile.py ./Dockerfile > ./Dockerfile.modified

        except Exception as e:
            print(f"处理文件时发生错误: {e}")
            sys.exit(1)
