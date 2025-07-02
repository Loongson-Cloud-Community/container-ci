#!/bin/bash

# 测试 Node.js 镜像基本功能
echo "=== 开始 Node.js 镜像测试 ==="

# 1. 检查 Node.js 和 npm 版本
echo -e "\n1. 检查 Node.js 和 npm 版本:"
node --version || { echo "Node.js 不可用"; exit 1; }
npm --version || { echo "npm 不可用"; exit 1; }

# 2. 创建测试目录
TEST_DIR="/tmp/node_test_$(date +%s)"
mkdir -p $TEST_DIR
cd $TEST_DIR
echo -e "\n2. 创建测试目录: $TEST_DIR"

# 3. 测试基本 JavaScript 执行
echo -e "\n3. 测试 JavaScript 执行:"
echo "console.log('Node.js 基本测试通过');" > test.js
node test.js || { echo "JavaScript 执行失败"; exit 1; }

# 4. 测试 npm 初始化
echo -e "\n4. 测试 npm 初始化:"
npm init -y || { echo "npm 初始化失败"; exit 1; }

# 5. 测试模块安装和使用
echo -e "\n5. 测试模块安装:"
npm install lodash || { echo "npm 模块安装失败"; exit 1; }

echo "const _ = require('lodash'); 
console.log('Lodash 版本:', _.VERSION); 
console.log('测试数组:', _.chunk([1,2,3,4], 2));" > test_module.js

node test_module.js || { echo "模块加载测试失败"; exit 1; }

# 6. 测试 HTTP 服务器
echo -e "\n6. 测试 HTTP 服务器:"
echo "const http = require('http');
const server = http.createServer((req, res) => {
  res.end('HTTP 测试通过');
});
server.listen(0, () => {
  console.log('临时 HTTP 服务器运行在端口:', server.address().port);
  // 自动测试请求
  const req = http.get('http://localhost:' + server.address().port, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
      console.log('HTTP 响应:', data);
      server.close();
    });
  });
});" > test_http.js

node test_http.js || { echo "HTTP 服务器测试失败"; exit 1; }

# 7. 清理测试目录
echo -e "\n7. 清理测试目录"
rm -rf $TEST_DIR

echo -e "\n=== 所有测试通过 ==="
