#!/bin/bash

# 快速设置Git提交规范
# 一键配置所有必要的工具和规则

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

echo "=========================================="
echo "  MiniBlog Git提交规范快速设置"
echo "=========================================="

# 检查Node.js
if ! command -v node &> /dev/null; then
    warning_msg "Node.js未安装，请先安装Node.js"
    echo "安装方法："
    echo "  Ubuntu/Debian: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
    echo "  macOS: brew install node"
    echo "  或访问: https://nodejs.org/"
    exit 1
fi

info_msg "Node.js版本: $(node --version)"

# 安装依赖
echo ""
echo "第1步：安装依赖包"
npm install

# 初始化Husky
echo ""
echo "第2步：初始化Git Hooks"
npx husky install

# 添加commit-msg hook
npx husky add .husky/commit-msg 'npx --no-install commitlint --edit "$1"'

# 设置Git配置
echo ""
echo "第3步：配置Git"
git config commit.template .gitmessage
git config alias.cz '!npx git-cz'
git config alias.cm 'commit -m'

success_msg "Git提交规范设置完成！"

echo ""
echo "🚀 使用方法："
echo "  交互式提交: git cz"
echo "  普通提交: git commit -m \"feat(scope): description\""
echo ""
echo "📝 提交格式："
echo "  feat(auth): add user login"
echo "  fix(db): resolve timeout issue"
echo "  docs(readme): update guide"
echo ""
echo "📖 完整规范: docs/commit-convention.md"