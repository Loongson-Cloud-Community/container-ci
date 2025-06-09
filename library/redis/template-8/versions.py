#!/usr/bin/env python3

from typing import List, Dict, Optional, Any, Union
import requests
import os
import re
import json
import sys

# GitHub原始数据URL
GITHUB_RAW_URL = "https://raw.githubusercontent.com/redis/redis-hashes/master/README"

# 代理配置（从环境变量读取）
PROXY_CONFIG = {
    "http": os.environ.get('http_proxy'),
    "https": os.environ.get('https_proxy')
}

VERSIONS_TEMPLATE_JSON = 'versions-template.json'
VERSIONS_JSON = 'versions.json'

class JsonFile:
    '''
    json 操作类
    '''
    @staticmethod
    def read(
        filename: str,
        encoding: str = "utf-8",
        default: Optional[Union[Dict, List]] = None,
    ) -> Union[Dict, List]:
        """
        从 JSON 文件读取数据
        :param filename: 文件名
        :param encoding: 文件编码（默认 utf-8）
        :param default: 如果文件不存在或解析失败，返回的默认值
        :return: 解析后的字典或列表
        """
        try:
            with open(filename, "r", encoding=encoding) as file:
                return json.load(file)
        except (FileNotFoundError, json.JSONDecodeError):
            if default is not None:
                return default
            raise  # 如果未提供默认值，则抛出异常

    @staticmethod
    def write(
        filename: str,
        data: Any,
        encoding: str = "utf-8",
        indent: Optional[int] = 4,
        ensure_ascii: bool = False,
    ) -> None:
        """
        将数据写入 JSON 文件
        :param filename: 文件名
        :param data: 要写入的数据（字典、列表等）
        :param encoding: 文件编码（默认 utf-8）
        :param indent: 缩进空格数（None 表示紧凑格式）
        :param ensure_ascii: 是否转义非 ASCII 字符（默认 False，支持中文）
        """
        with open(filename, "w", encoding=encoding) as file:
            json.dump(
                data,
                file,
                indent=indent,
                ensure_ascii=ensure_ascii,
            )

def parse_line(redis_version_info: str) -> Optional[Dict]:
    '''
    参数:
        redis_version_info(str): 'hash redis-7.2.9.tar.gz sha256 2343cc49db3beb9d2925a44e13032805a608821a58f25bd874c84881115a20b7 http://download.redis.io/releases/redis-7.2.9.tar.gz'

    返回:
        {'file': 'redis-7.2.9.tar.gz', 'version': '7.2.9', 'type': 'sha256', 'sum': '2343cc49db3beb9d2925a44e13032805a608821a58f25bd874c84881115a20b7', 'url': 'http://download.redis.io/releases/redis-7.2.9.tar.gz'}
    '''
    pattern = re.compile(r'''
        ^hash[\t ]+                                 # 行以 hash 开头
        (?P<file>redis-                             # 获取文件名
            (?P<version>[0-9.]+)\.[^\s]+            # 获取版本号
        )[\t ]+
        (?P<type>sha256|sha1)[\t ]+                 # 校验类型type
        (?P<sum>[0-9a-z]{64}|[0-9a-z]{40})[\t ]+    # 校验和
        (?P<url>[^\s]+)[\t ]*                       # 下载地址
        $
    ''', re.VERBOSE)
    match = pattern.search(redis_version_info)
    if match:
        return match.groupdict()
    else:
        return None

def fetch_and_process_redis_version(version: 'str'):
    """从GitHub获取Redis版本信息，并处理特定版本（8.0.1）"""

    try:
        # 1. 发起HTTP请求获取版本信息
        response = requests.get(GITHUB_RAW_URL, proxies=PROXY_CONFIG)
        response.raise_for_status()  # 检查HTTP状态码是否成功

        # 2. 逐行处理版本信息
        for version_line in response.text.rstrip('\n').split('\n'):
            # 解析单行版本数据
            version_data = parse_line(version_line)
            
            # 3. 只处理目标版本 8.0.1
            if version_data and version_data['version'] == version:
                # 加载版本模板文件
                version_template = JsonFile.read(VERSIONS_TEMPLATE_JSON)
                
                # 准备版本元数据
                version_metadata = version_template['*']  # 获取模板基础结构
                checksum_type = version_data['type']     # 校验和类型（如sha256）

                # 4. 更新元数据字段
                version_metadata.update({
                    'version': version_data['version'],  # 完整版本号
                    checksum_type: version_data['sum'],  # 校验和值
                    'url': version_data['url']           # 下载地址
                })
          
                # 5. 构建最终结果并写入文件
                version_result = {version: version_metadata}
                JsonFile.write(VERSIONS_JSON, version_result)

    except requests.exceptions.RequestException as error:
        print(f"请求失败: {error}")

if __name__ == '__main__':
    version = sys.argv[1]
    fetch_and_process_redis_version(version)
