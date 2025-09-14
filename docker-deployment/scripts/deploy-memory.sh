#!/bin/bash

# MiniBlog 内存数据库部署脚本（单容器）

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

warning_msg() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "=========================================="
echo "  MiniBlog 内存数据库部署（单容器）"
echo "=========================================="

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    error_exit "Docker未安装，请先安装Docker"
fi

# 检查镜像是否存在
if ! docker images | grep -q "miniblog.*latest"; then
    warning_msg "未找到miniblog镜像，正在构建..."
    if [ -f "docker-deployment/scripts/build-image.sh" ]; then
        ./docker-deployment/scripts/build-image.sh
    else
        error_exit "请先运行 ./docker-deployment/scripts/build-image.sh 构建镜像"
    fi
fi

info_msg "开始部署 MiniBlog (内存数据库模式)..."

echo ""
echo "第1步：清理可能存在的旧容器"
docker stop miniblog-memory 2>/dev/null || true
docker rm miniblog-memory 2>/dev/null || true
success_msg "旧容器清理完成"

echo ""
echo "第2步：准备配置文件"
CONFIG_DIR="/tmp/miniblog-memory-config"
mkdir -p "$CONFIG_DIR"

# 复制配置文件
cp docker-deployment/configs/memory-db.yaml "$CONFIG_DIR/mb-apiserver.yaml"
success_msg "配置文件准备完成"

echo ""
echo "第3步：启动应用容器"
info_msg "正在启动MiniBlog容器（内存数据库模式）..."

docker run -d \
  --name miniblog-memory \
  -p 5555:5555 \
  -p 6666:6666 \
  -v "$CONFIG_DIR/mb-apiserver.yaml:/opt/miniblog/configs/mb-apiserver.yaml" \
  --restart unless-stopped \
  miniblog:latest \
  --config=/opt/miniblog/configs/mb-apiserver.yaml

if [ $? -eq 0 ]; then
    success_msg "容器启动成功"
else
    error_exit "容器启动失败"
fi

echo ""
echo "第4步：等待服务启动"
info_msg "等待应用完全启动（最多30秒）..."
for i in {1..30}; do
    if curl -s http://localhost:5555/healthz > /dev/null 2>&1; then
        success_msg "应用已就绪 (用时 ${i} 秒)"
        break
    fi
    if [ $i -eq 30 ]; then
        warning_msg "应用启动可能有问题，请检查日志"
    fi
    echo -n "."
    sleep 1
done

echo ""
echo "第5步：部署验证"
info_msg "验证服务状态..."

# 检查容器状态
echo "容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep miniblog-memory

# 测试健康检查
echo ""
echo "健康检查测试:"
HEALTH_RESPONSE=$(curl -s http://localhost:5555/healthz)
if [ $? -eq 0 ]; then
    success_msg "健康检查通过: $HEALTH_RESPONSE"
else
    warning_msg "健康检查失败，请检查应用日志"
fi

# 显示资源使用情况
echo ""
echo "资源使用情况:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep miniblog-memory

echo ""
echo "=========================================="
success_msg "MiniBlog 内存数据库模式部署完成！"
echo "=========================================="

echo ""
echo "📋 部署信息:"
echo "   • 部署模式: 内存数据库（单容器）"
echo "   • 容器名称: miniblog-memory"
echo "   • HTTP API: http://localhost:5555"
echo "   • gRPC API: localhost:6666"
echo "   • 健康检查: http://localhost:5555/healthz"

echo ""
echo "⚠️  重要提醒:"
echo "   • 数据存储在内存中，重启后会丢失"
echo "   • 适合开发和测试环境"
echo "   • 生产环境请使用MariaDB模式"

echo ""
echo "🔧 管理命令:"
echo "   • 查看日志: docker logs -f miniblog-memory"
echo "   • 停止服务: docker stop miniblog-memory"
echo "   • 重启服务: docker restart miniblog-memory"
echo "   • 删除容器: docker rm -f miniblog-memory"

echo ""
echo "🧪 测试部署:"
echo "   • 运行测试: ./docker-deployment/scripts/test-deployment.sh memory"

echo ""
info_msg "部署完成！你现在有一个运行在Docker中的MiniBlog系统。"