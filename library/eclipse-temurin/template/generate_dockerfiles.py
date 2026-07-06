#!/usr/bin/env python3
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import argparse
import json
import operator
import os
import re
import shutil
import sys

import requests
import requests_cache
import yaml
from jinja2 import Environment, FileSystemLoader

from adoptium_api import get_supported_versions
from eol_checker import print_eol_warnings

requests_cache.install_cache("adoptium_cache", expire_after=3600)


VERSION_OPERATORS = {
    "==": operator.eq,
    "!=": operator.ne,
    ">=": operator.ge,
    "<=": operator.le,
    ">": operator.gt,
    "<": operator.lt,
}

VERSION_CONDITION_RE = re.compile(r"^(==|!=|>=|<=|>|<)(\d+)$")


def resolve_architectures(default_architectures, overrides, version):
    """Resolve effective architectures for a given version by applying overrides.

    All matching overrides are applied in order. Each override has a 'versions'
    string (e.g. '==8', '<=11', '>17') and either:
      - 'exclude': list of architectures to remove
      - 'include': list of architectures to add
      - 'architectures': full replacement list (overrides default entirely)
    """
    if not overrides:
        return default_architectures

    result = list(default_architectures)
    for override in overrides:
        condition = override["versions"].strip()
        match = VERSION_CONDITION_RE.match(condition)
        if not match:
            raise ValueError(f"Invalid version condition: '{condition}'")
        op_str, target = match.groups()
        if VERSION_OPERATORS[op_str](version, int(target)):
            if "architectures" in override:
                result = list(override["architectures"])
            if "exclude" in override:
                result = [a for a in result if a not in override["exclude"]]
            if "include" in override:
                result = result + [a for a in override["include"] if a not in result]

    return result


def archHelper(arch, os_name):
    if arch == "aarch64" and os_name == "ubuntu":
        return "arm64"
    elif arch == "ppc64le" and os_name == "ubuntu":
        return "ppc64el"
    elif arch == "arm":
        return "armhf"
    elif arch == "x64":
        if os_name == "ubuntu":
            return "amd64"
        else:
            return "x86_64"
    elif arch == "loongarch64":
        return "loongarch64"
    else:
        return arch


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate Dockerfiles for Eclipse Temurin images"
    )

    # 新增参数：指定大版本和架构
    parser.add_argument("--version", type=int, help="Only generate for this major version (e.g., 8, 11)", default=None)
    parser.add_argument("--arch", help="Only generate for this architecture (e.g., loongarch64)", default=None)

    # Setup the Jinja2 environment
    env = Environment(
        loader=FileSystemLoader("docker_templates"), trim_blocks=False, lstrip_blocks=False
    )

    headers = {
        "User-Agent": "Adoptium Dockerfile Updater",
    }

    # Flag for force removing old Dockerfiles
    parser.add_argument("--force", action="store_true", help="Force remove old Dockerfiles")

    args = parser.parse_args()

    # Remove old Dockerfiles if --force is set
    if args.force:
        # Remove all top level dirs that are numbers
        for dir in os.listdir():
            if dir.isdigit():
                print(f"Removing {dir}")
                shutil.rmtree(dir)

    # 加载本地 versions.json（用于 loongarch64 自定义构建）
    versions_data = {}
    versions_json_path = "versions.json"
    if os.path.exists(versions_json_path):
        with open(versions_json_path, "r") as f:
            versions_data = json.load(f)
        print(f"Loaded versions.json with {len(versions_data)} entries")
    else:
        print("Warning: versions.json not found, loongarch64 custom builds will be skipped")

    # Load the YAML configuration
    with open("config/temurin.yml", "r") as file:
        config = yaml.safe_load(file)

    # Global architecture overrides apply to all configurations
    global_architecture_overrides = config.get("architecture_overrides", [])

    # Fetch supported versions from the Adoptium API (only used for non-loongarch)
    supported_versions = get_supported_versions()

    # Iterate through OS families and then configurations
    # Check for expired distros
    print_eol_warnings(config)

    for os_family, configurations in config["configurations"].items():
        for configuration in configurations:
            directory = configuration["directory"]
            default_architectures = configuration["architectures"]

            # 如果指定了 --arch，只处理包含该架构的配置
            if args.arch and args.arch not in default_architectures:
                print(f"Skipping {directory} (architecture {args.arch} not in {default_architectures})")
                continue

            # 如果指定了 --arch，强制只生成该架构
            if args.arch:
                architectures_to_generate = [args.arch]
            else:
                architectures_to_generate = default_architectures

            local_overrides = configuration.get("architecture_overrides", [])
            architecture_overrides = global_architecture_overrides + local_overrides
            os_name = configuration["os"]
            base_image = configuration["image"]
            deprecated = configuration.get("deprecated", None)
            versions = configuration.get("versions", supported_versions)

            # 确定模板名
            if os_family == "alpine-linux" and "loongarch64" in architectures_to_generate:
                template_name = "alpine-loongarch.Dockerfile.j2"
            else:
                template_name = f"{os_name}.Dockerfile.j2"
            template = env.get_template(template_name)

            # Create output directories if they don't exist
            for version in versions:
                # 如果指定了 --version，只处理该版本
                if args.version is not None and version != args.version:
                    continue

                # if deprecated is set and version is greater than or equal to deprecated, skip
                if deprecated and version >= deprecated:
                    continue

                # 解析架构（可能受 overrides 影响）
                resolved_architectures = resolve_architectures(
                    default_architectures, architecture_overrides, version
                )
                # 如果指定了 --arch，确保只生成该架构
                if args.arch:
                    resolved_architectures = [args.arch]

                print("Generating Dockerfiles for", base_image, "-", version)
                for image_type in ["jdk", "jre"]:
                    output_directory = os.path.join(str(version), image_type, directory)
                    os.makedirs(output_directory, exist_ok=True)

                    # ----- 处理 loongarch64 自定义构建 -----
                    use_custom_loongarch = False
                    tarball_name = None  # 初始化
                    if args.arch == "loongarch64":
                        ver_key = str(version)
                        if ver_key in versions_data:
                            full_version = versions_data[ver_key].get("version")
                            if not full_version:
                                print(f"Warning: version {ver_key} missing 'version' field, skipping")
                                continue
                            # 从 versions.json 获取 tarball 名称
                            tarball_name = versions_data[ver_key]["tarball"].get(image_type)
                            if not tarball_name or tarball_name == "null":
                                print(f"Error: tarball name missing for {image_type} version {version}, skipping")
                                continue
                            openjdk_version = full_version
                            arch_data = {}
                            use_custom_loongarch = True
                            print(f"Using custom loongarch64 version {full_version} with tarball {tarball_name}")
                        else:
                            print(f"Warning: version {ver_key} not found in versions.json, skipping")
                            continue

                    if not use_custom_loongarch:
                        # ----- 非 loongarch64：使用 Adoptium API -----
                        url = f"https://api.adoptium.net/v3/assets/feature_releases/{version}/ga?page=0&image_type={image_type}&os={os_family}&page_size=1&vendor=eclipse"
                        response = requests.get(url, headers=headers)

                        # Handle 404 errors gracefully - skip this version if not available
                        if response.status_code == 404:
                            print(f"Version {version} not available for {image_type} on {os_family}, skipping...")
                            continue

                        response.raise_for_status()
                        data = response.json()

                        release = response.json()[0]

                        # Extract the version number from the release name
                        openjdk_version = release["release_name"]

                        # If version doesn't equal 8, get the more accurate version number
                        if version != 8:
                            openjdk_version = (
                                "jdk-" + release["version_data"]["openjdk_version"]
                            )
                            # if openjdk_version contains -LTS remove it
                            if "-LTS" in openjdk_version:
                                openjdk_version = openjdk_version.replace("-LTS", "")

                        # Generate the data for each architecture
                        arch_data = {}

                        for binary in release["binaries"]:
                            if (
                                binary["architecture"] in resolved_architectures
                                and binary["os"] == os_family
                            ):
                                if os_family == "windows":
                                    # Windows only has x64 binaries
                                    copy_from = openjdk_version.replace(
                                        "jdk", ""
                                    )  # jdk8u292-b10 -> 8u292-b10
                                    if version != 8:
                                        copy_from = copy_from.replace("-", "").replace(
                                            "+", "_"
                                        )  # 11.0.11+9 -> 11.0.11_9
                                    copy_from = f"{copy_from}-{image_type}-windowsservercore-{base_image.split(':')[1]}"
                                    arch_data = {
                                        "download_url": binary["installer"]["link"],
                                        "checksum": binary["installer"]["checksum"],
                                        "copy_from": copy_from,
                                    }
                                else:
                                    arch_data[archHelper(binary["architecture"], os_name)] = {
                                        "download_url": binary["package"]["link"],
                                        "checksum": binary["package"]["checksum"],
                                    }
                            else:
                                continue

                        # If arch_data is empty, skip
                        if not arch_data:
                            continue

                        # Sort arch_data by key
                        arch_data = dict(sorted(arch_data.items()))

                    # ----- 渲染 Dockerfile -----
                    # 对于 loongarch64，我们传入 tarball_name（如果存在），否则为 None（模板中可能不使用）
                    # 对于非 loongarch，tarball_name 保持 None，模板不会使用它
                    rendered_dockerfile = template.render(
                        base_image=base_image,
                        image_type=image_type,
                        java_version=openjdk_version,
                        version=version,
                        arch_data=arch_data,
                        os_family=os_family,
                        os=os_name,
                        tarball_name=tarball_name,   # 新增，用于 Debian 模板
                    )

                    print("Writing Dockerfile to", output_directory)
                    # Save the rendered Dockerfile
                    with open(
                        os.path.join(output_directory, "Dockerfile"), "w"
                    ) as out_file:
                        out_file.write(rendered_dockerfile)

                    if os_family != "windows":
                        # Entrypoint is currently only needed for CA certificate handling, which is not (yet)
                        # available on Windows

                        # Generate entrypoint.sh
                        template_entrypoint_file = "entrypoint.sh.j2"
                        template_entrypoint = env.get_template(template_entrypoint_file)

                        entrypoint = template_entrypoint.render(
                            image_type=image_type,
                            os=os_name,
                            version=version,
                        )

                        with open(
                            os.path.join(output_directory, "entrypoint.sh"), "w"
                        ) as out_file:
                            out_file.write(entrypoint)

    print("Dockerfiles generated successfully!")
