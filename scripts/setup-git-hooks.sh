#!/bin/bash

# Git Hooks 设置脚本
# 用于配置Git提交规范检查

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}❌ 错误: $1${NC}" >&2
    exit 1
}

success_msg() {
    echo -e "${GREEN}✅ $1${NC}"
}

info_msg() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning_msg() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "=========================================="
echo "  Git Hooks 和提交规范设置"
echo "=========================================="

# 检查是否在Git仓库中
if [ ! -d ".git" ]; then
    error_exit "请在Git仓库根目录中运行此脚本"
fi

echo "第1步：检查Node.js环境"
if ! command -v node &> /dev/null; then
    warning_msg "Node.js未安装，正在安装..."
    
    # 检查系统类型并安装Node.js
    if command -v apt &> /dev/null; then
        # Ubuntu/Debian
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
        sudo yum install -y nodejs
    elif command -v brew &> /dev/null; then
        # macOS
        brew install node
    else
        error_exit "无法自动安装Node.js，请手动安装后重试"
    fi
fi

NODE_VERSION=$(node --version)
success_msg "Node.js版本: $NODE_VERSION"

echo ""
echo "第2步：安装依赖包"
info_msg "安装commitlint和husky..."

# 检查package.json是否存在
if [ ! -f "package.json" ]; then
    error_exit "package.json文件不存在，请确保在项目根目录运行"
fi

# 安装依赖
npm install
success_msg "依赖包安装完成"

echo ""
echo "第3步：初始化Husky"
info_msg "设置Git hooks..."

# 初始化husky
npx husky install

# 创建commit-msg hook
npx husky add .husky/commit-msg 'npx --no-install commitlint --edit "$1"'

# 创建pre-commit hook（可选，用于代码格式检查）
cat > .husky/pre-commit << 'EOF'
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

echo "🔍 运行pre-commit检查..."

# 检查Go代码格式
if command -v gofmt &> /dev/null; then
    UNFORMATTED=$(gofmt -l .)
    if [ -n "$UNFORMATTED" ]; then
        echo "❌ 以下文件需要格式化:"
        echo "$UNFORMATTED"
        echo "请运行: gofmt -w ."
        exit 1
    fi
    echo "✅ Go代码格式检查通过"
fi

# 检查是否有大文件
echo "🔍 检查大文件..."
git diff --cached --name-only | while read file; do
    if [ -f "$file" ]; then
        size=$(wc -c < "$file")
        if [ $size -gt 1048576 ]; then  # 1MB
            echo "❌ 文件 $file 大小为 $(($size / 1024))KB，超过1MB限制"
            exit 1
        fi
    fi
done

echo "✅ Pre-commit检查通过"
EOF

chmod +x .husky/pre-commit
success_msg "Git hooks设置完成"

echo ""
echo "第4步：配置Git提交模板"
info_msg "设置提交信息模板..."

# 设置Git提交模板
git config commit.template .gitmessage
success_msg "Git提交模板设置完成"

echo ""
echo "第5步：配置Git别名"
info_msg "设置便捷的Git别名..."

# 设置有用的Git别名
git config alias.cz '!npx git-cz'
git config alias.cm 'commit -m'
git config alias.co 'checkout'
git config alias.br 'branch'
git config alias.st 'status'
git config alias.lg 'log --oneline --graph --decorate --all'
git config alias.last 'log -1 HEAD'
git config alias.unstage 'reset HEAD --'

success_msg "Git别名设置完成"

echo ""
echo "第6步：创建提交规范检查脚本"
info_msg "创建本地验证脚本..."

cat > scripts/validate-commit.sh << 'EOF'
#!/bin/bash

# 提交信息验证脚本
# 用于本地验证提交信息是否符合规范

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat $COMMIT_MSG_FILE)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查提交信息格式
if ! echo "$COMMIT_MSG" | grep -qE '^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,50}$'; then
    echo -e "${RED}❌ 提交信息格式不正确！${NC}"
    echo ""
    echo -e "${YELLOW}正确格式：${NC}"
    echo "  <type>[optional scope]: <description>"
    echo ""
    echo -e "${YELLOW}示例：${NC}"
    echo "  feat(auth): add user login functionality"
    echo "  fix(db): resolve connection timeout issue"
    echo "  docs(readme): update installation guide"
    echo ""
    echo -e "${YELLOW}支持的类型：${NC}"
    echo "  feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert"
    echo ""
    echo -e "${YELLOW}当前提交信息：${NC}"
    echo "  $COMMIT_MSG"
    exit 1
fi

echo -e "${GREEN}✅ 提交信息格式正确${NC}"
exit 0
EOF

chmod +x scripts/validate-commit.sh
success_msg "验证脚本创建完成"

echo ""
echo "第7步：测试配置"
info_msg "测试commitlint配置..."

# 测试commitlint配置
echo "feat(test): test commit message format" | npx commitlint
if [ $? -eq 0 ]; then
    success_msg "Commitlint配置测试通过"
else
    error_exit "Commitlint配置测试失败"
fi

echo ""
echo "=========================================="
success_msg "Git提交规范设置完成！"
echo "=========================================="

echo ""
echo "📋 配置摘要:"
echo "   • Commitlint: 已配置并测试"
echo "   • Husky: 已安装Git hooks"
echo "   • 提交模板: 已设置"
echo "   • Git别名: 已配置"
echo "   • Pre-commit检查: 已启用"

echo ""
echo "🚀 使用方法:"
echo "   • 规范提交: git cz (交互式提交)"
echo "   • 普通提交: git commit -m \"feat(scope): description\""
echo "   • 查看模板: git config --get commit.template"
echo "   • 查看别名: git config --get-regexp alias"

echo ""
echo "📝 提交格式示例:"
echo "   • feat(auth): add user login functionality"
echo "   • fix(db): resolve connection timeout issue"
echo "   • docs(readme): update installation guide"
echo "   • refactor(api): simplify error handling"

echo ""
echo "⚠️  重要提醒:"
echo "   • 每次提交都会自动检查格式"
echo "   • 不符合规范的提交会被拒绝"
echo "   • 使用 'git cz' 可以交互式生成规范提交"
echo "   • 查看完整规范: docs/commit-convention.md"

echo ""
info_msg "现在你可以开始使用规范的Git提交了！"