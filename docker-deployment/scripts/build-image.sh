#!/bin/bash

# MiniBlog Docker镜像构建脚本

set -e

# 设置颜色输出
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

echo "=========================================="
echo "  MiniBlog Docker 镜像构建"
echo "=========================================="

# 检查是否在项目根目录
if [ ! -f "go.mod" ] || [ ! -f "Makefile" ]; then
    error_exit "请在项目根目录运行此脚本"
fi

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    error_exit "Docker未安装，请先安装Docker"
fi

echo "第1步：编译Go程序"
info_msg "正在编译mb-apiserver..."
make build BINS=mb-apiserver || error_exit "编译失败"

if [ ! -f "_output/platforms/linux/amd64/mb-apiserver" ]; then
    error_exit "编译后的程序不存在"
fi
success_msg "Go程序编译完成"

echo ""
echo "第2步：准备Docker构建环境"
BUILD_DIR="docker-deployment/build"
mkdir -p "$BUILD_DIR"

# 复制编译后的程序
cp _output/platforms/linux/amd64/mb-apiserver "$BUILD_DIR/"
success_msg "程序文件已复制到构建目录"

echo ""
echo "第3步：创建优化的Dockerfile"
cat > "$BUILD_DIR/Dockerfile" << 'EOF'
# 使用轻量级的Alpine Linux作为基础镜像
FROM alpine:3.18

# 安装必要的工具和时区数据
RUN apk add --no-cache tzdata ca-certificates && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# 创建非root用户（安全最佳实践）
RUN addgroup -g 1000 miniblog && \
    adduser -D -s /bin/sh -u 1000 -G miniblog miniblog

# 创建应用目录
RUN mkdir -p /opt/miniblog/bin /opt/miniblog/configs /opt/miniblog/log && \
    chown -R miniblog:miniblog /opt/miniblog

# 复制编译好的程序
COPY mb-apiserver /opt/miniblog/bin/mb-apiserver

# 给程序执行权限
RUN chmod +x /opt/miniblog/bin/mb-apiserver && \
    chown miniblog:miniblog /opt/miniblog/bin/mb-apiserver

# 切换到非root用户
USER miniblog

# 设置工作目录
WORKDIR /opt/miniblog

# 暴露端口
EXPOSE 5555 6666

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5555/healthz || exit 1

# 设置启动命令
ENTRYPOINT ["/opt/miniblog/bin/mb-apiserver"]
EOF
success_msg "Dockerfile已创建"

echo ""
echo "第4步：构建Docker镜像"
info_msg "正在构建Docker镜像..."

# 构建镜像
docker build -t miniblog:latest "$BUILD_DIR/" || error_exit "Docker镜像构建失败"

# 添加版本标签
VERSION=$(date +%Y%m%d-%H%M%S)
docker tag miniblog:latest "miniblog:$VERSION"

success_msg "Docker镜像构建成功"

echo ""
echo "第5步：验证镜像"
info_msg "验证构建的镜像..."

# 检查镜像是否存在
if docker images | grep -q "miniblog.*latest"; then
    success_msg "镜像验证通过"
else
    error_exit "镜像验证失败"
fi

# 显示镜像信息
echo ""
echo "构建的镜像:"
docker images | grep miniblog

echo ""
echo "镜像详细信息:"
docker inspect miniblog:latest --format='{{.Config.ExposedPorts}}' | grep -o '[0-9]*/tcp' | tr '\n' ' '
echo ""

echo ""
echo "=========================================="
success_msg "Docker镜像构建完成！"
echo "=========================================="

echo ""
echo "📋 构建信息:"
echo "   • 镜像名称: miniblog:latest"
echo "   • 版本标签: miniblog:$VERSION"
echo "   • 基础镜像: alpine:3.18"
echo "   • 暴露端口: 5555 (HTTP), 6666 (gRPC)"

echo ""
echo "🚀 下一步:"
echo "   • 内存数据库部署: ./scripts/deploy-memory.sh"
echo "   • MariaDB数据库部署: ./scripts/deploy-mariadb.sh"

# 清理构建目录
rm -rf "$BUILD_DIR"
info_msg "构建临时文件已清理"