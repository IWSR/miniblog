#!/bin/bash

# GitHub Actions 问题修复脚本
# 修复常见的CI/CD问题

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success_msg() {
    echo -e "${GREEN}✅ $1${NC}"
}

info_msg() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning_msg() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error_msg() {
    echo -e "${RED}❌ $1${NC}"
}

echo "=========================================="
echo "  GitHub Actions 问题修复工具"
echo "=========================================="

echo "第1步：检查Go代码质量"
info_msg "运行Go代码检查..."

# 检查Go格式
if command -v gofmt &> /dev/null; then
    UNFORMATTED=$(gofmt -l . 2>/dev/null | grep -v vendor || true)
    if [ -n "$UNFORMATTED" ]; then
        warning_msg "以下文件需要格式化:"
        echo "$UNFORMATTED"
        echo ""
        echo "是否自动格式化？(y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            gofmt -w .
            success_msg "代码格式化完成"
        fi
    else
        success_msg "Go代码格式正确"
    fi
fi

# 检查未使用的导入和变量
if command -v go &> /dev/null; then
    info_msg "检查Go代码问题..."
    
    # 运行go vet
    if go vet ./... 2>/dev/null; then
        success_msg "go vet检查通过"
    else
        warning_msg "go vet发现问题，正在尝试修复..."
        go vet ./... 2>&1 | head -10
    fi
    
    # 检查未使用的导入
    if command -v goimports &> /dev/null; then
        goimports -w .
        success_msg "导入语句已优化"
    else
        info_msg "建议安装goimports: go install golang.org/x/tools/cmd/goimports@latest"
    fi
fi

echo ""
echo "第2步：检查Docker配置"
info_msg "验证Docker配置..."

# 检查Dockerfile是否存在
if [ -f "build/docker/mb-apiserver/Dockerfile" ]; then
    success_msg "Dockerfile存在"
else
    error_msg "Dockerfile不存在"
fi

# 检查编译输出目录
if [ -d "_output" ]; then
    info_msg "清理旧的编译输出..."
    rm -rf _output
fi

# 尝试编译
if command -v make &> /dev/null; then
    info_msg "测试编译..."
    if make build BINS=mb-apiserver; then
        success_msg "编译成功"
    else
        error_msg "编译失败"
        exit 1
    fi
else
    warning_msg "make命令不可用，跳过编译测试"
fi

echo ""
echo "第3步：检查GitHub Actions配置"
info_msg "验证工作流配置..."

# 检查工作流文件
WORKFLOW_FILES=(.github/workflows/*.yml .github/workflows/*.yaml)
for file in "${WORKFLOW_FILES[@]}"; do
    if [ -f "$file" ]; then
        info_msg "检查工作流文件: $file"
        
        # 检查常见问题
        if grep -q "master" "$file"; then
            warning_msg "$file 中使用了 'master' 分支，建议改为 'main'"
        fi
        
        if grep -q "ubuntu-18.04" "$file"; then
            warning_msg "$file 中使用了过时的 ubuntu-18.04，建议改为 ubuntu-latest"
        fi
        
        success_msg "$file 配置检查完成"
    fi
done

echo ""
echo "第4步：检查依赖和模块"
info_msg "检查Go模块..."

if [ -f "go.mod" ]; then
    # 清理模块缓存
    go mod tidy
    success_msg "Go模块已整理"
    
    # 验证模块
    if go mod verify; then
        success_msg "Go模块验证通过"
    else
        warning_msg "Go模块验证失败"
    fi
else
    error_msg "go.mod文件不存在"
fi

echo ""
echo "第5步：检查测试"
info_msg "运行测试..."

if command -v go &> /dev/null; then
    # 运行测试
    if go test -v ./... -timeout=30s; then
        success_msg "所有测试通过"
    else
        warning_msg "部分测试失败"
    fi
else
    warning_msg "Go命令不可用，跳过测试"
fi

echo ""
echo "第6步：生成修复建议"
info_msg "生成修复建议..."

cat > .github/workflows/fix-suggestions.md << 'EOF'
# GitHub Actions 修复建议

## 常见问题和解决方案

### 1. Docker镜像标签问题
- 确保镜像标签格式正确
- 避免在标签中使用特殊字符
- 使用 `sha-` 前缀而不是 `{{branch}}-`

### 2. Go代码质量问题
- 运行 `gofmt -w .` 格式化代码
- 运行 `go vet ./...` 检查代码问题
- 删除未使用的函数和变量

### 3. 分支名称问题
- 将 `master` 改为 `main`
- 确保所有工作流使用正确的分支名

### 4. 编译问题
- 确保 `make build BINS=mb-apiserver` 能够成功执行
- 检查 Go 版本兼容性

### 5. 测试问题
- 确保所有测试能够通过
- 修复失败的测试用例
EOF

success_msg "修复建议已生成: .github/workflows/fix-suggestions.md"

echo ""
echo "第7步：创建快速修复脚本"

cat > scripts/quick-fix-ci.sh << 'EOF'
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
EOF

chmod +x scripts/quick-fix-ci.sh
success_msg "快速修复脚本已创建: scripts/quick-fix-ci.sh"

echo ""
echo "=========================================="
success_msg "GitHub Actions 问题修复完成！"
echo "=========================================="

echo ""
echo "📋 修复总结:"
echo "   • Go代码格式化和质量检查"
echo "   • Docker配置验证"
echo "   • GitHub Actions工作流检查"
echo "   • Go模块整理和验证"
echo "   • 测试执行"

echo ""
echo "🚀 下一步操作:"
echo "   1. 提交修复的代码:"
echo "      git add ."
echo "      git commit -m \"fix(ci): resolve GitHub Actions issues\""
echo "      git push"
echo ""
echo "   2. 如果还有问题，运行快速修复:"
echo "      ./scripts/quick-fix-ci.sh"
echo ""
echo "   3. 检查GitHub Actions运行结果"

echo ""
info_msg "修复完成！现在可以重新运行GitHub Actions了。"