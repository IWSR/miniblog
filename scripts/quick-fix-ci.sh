#!/bin/bash

# 快速修复CI问题

echo "🔧 快速修复CI问题..."

# 格式化Go代码
if command -v gofmt &> /dev/null; then
    echo "格式化Go代码..."
    gofmt -w .
fi

# 整理Go模块
if command -v go &> /dev/null; then
    echo "整理Go模块..."
    go mod tidy
    go mod verify
fi

# 清理编译输出
echo "清理编译输出..."
rm -rf _output

# 测试编译
if command -v make &> /dev/null; then
    echo "测试编译..."
    make build BINS=mb-apiserver
fi

echo "✅ 快速修复完成！"
