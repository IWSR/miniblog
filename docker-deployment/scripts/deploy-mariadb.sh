#!/bin/bash

# MiniBlog MariaDB数据库部署脚本（双容器）

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
echo "  MiniBlog MariaDB数据库部署（双容器）"
echo "=========================================="

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    error_exit "Docker未安装，请先安装Docker"
fi

# 检查应用镜像是否存在
if ! docker images | grep -q "miniblog.*latest"; then
    warning_msg "未找到miniblog镜像，正在构建..."
    if [ -f "docker-deployment/scripts/build-image.sh" ]; then
        ./docker-deployment/scripts/build-image.sh
    else
        error_exit "请先运行 ./docker-deployment/scripts/build-image.sh 构建镜像"
    fi
fi

# 检查SQL文件是否存在
if [ ! -f "configs/miniblog.sql" ]; then
    error_exit "找不到数据库初始化文件 configs/miniblog.sql"
fi

info_msg "开始部署 MiniBlog (MariaDB模式)..."

echo ""
echo "第1步：清理可能存在的旧资源"
docker stop miniblog-app-mariadb miniblog-mariadb 2>/dev/null || true
docker rm miniblog-app-mariadb miniblog-mariadb 2>/dev/null || true
docker network rm miniblog-network 2>/dev/null || true
success_msg "旧资源清理完成"

echo ""
echo "第2步：创建Docker网络"
docker network create miniblog-network || error_exit "创建网络失败"
success_msg "Docker网络 'miniblog-network' 创建成功"

echo ""
echo "第3步：启动MariaDB容器"
info_msg "正在拉取MariaDB镜像并启动容器..."
docker run -d \
  --name miniblog-mariadb \
  --network miniblog-network \
  -e MYSQL_ROOT_PASSWORD=root123456 \
  -e MYSQL_DATABASE=miniblog \
  -e MYSQL_USER=miniblog \
  -e MYSQL_PASSWORD=miniblog1234 \
  -e MYSQL_CHARSET=utf8mb4 \
  -e MYSQL_COLLATION=utf8mb4_unicode_ci \
  -p 3306:3306 \
  -v miniblog-db-data:/var/lib/mysql \
  --restart unless-stopped \
  mariadb:10.11 \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci \
  --default-authentication-plugin=mysql_native_password

if [ $? -eq 0 ]; then
    success_msg "MariaDB容器启动成功"
else
    error_exit "MariaDB容器启动失败"
fi

echo ""
echo "第4步：等待数据库初始化"
info_msg "等待MariaDB完全启动（最多60秒）..."
for i in {1..60}; do
    if docker exec miniblog-mariadb mysqladmin ping -h localhost -u root -proot123456 --silent &> /dev/null; then
        success_msg "数据库已就绪 (用时 ${i} 秒)"
        break
    fi
    if [ $i -eq 60 ]; then
        error_exit "数据库启动超时"
    fi
    echo -n "."
    sleep 1
done

echo ""
echo "第5步：初始化数据库表结构"
info_msg "导入数据库结构和初始数据..."
docker cp configs/miniblog.sql miniblog-mariadb:/tmp/miniblog.sql
docker exec miniblog-mariadb mysql -u root -proot123456 -e "source /tmp/miniblog.sql"

if [ $? -eq 0 ]; then
    success_msg "数据库表结构初始化完成"
else
    error_exit "数据库初始化失败"
fi

# 验证数据库表是否创建成功
info_msg "验证数据库表..."
TABLES=$(docker exec miniblog-mariadb mysql -u miniblog -pminiblog1234 miniblog -e "SHOW TABLES;" -s)
echo "已创建的表: $TABLES"

echo ""
echo "第6步：准备应用配置文件"
CONFIG_DIR="/tmp/miniblog-mariadb-config"
mkdir -p "$CONFIG_DIR"
cp docker-deployment/configs/mariadb.yaml "$CONFIG_DIR/mb-apiserver.yaml"
success_msg "应用配置文件准备完成"

echo ""
echo "第7步：启动应用容器"
info_msg "启动MiniBlog应用容器..."
docker run -d \
  --name miniblog-app-mariadb \
  --network miniblog-network \
  -p 5555:5555 \
  -p 6666:6666 \
  -v "$CONFIG_DIR/mb-apiserver.yaml:/opt/miniblog/configs/mb-apiserver.yaml" \
  --restart unless-stopped \
  miniblog:latest \
  --config=/opt/miniblog/configs/mb-apiserver.yaml

if [ $? -eq 0 ]; then
    success_msg "应用容器启动成功"
else
    error_exit "应用容器启动失败"
fi

echo ""
echo "第8步：等待应用启动"
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
echo "第9步：部署验证"
info_msg "验证服务状态..."

# 检查容器状态
echo "容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep miniblog

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
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep miniblog

echo ""
echo "=========================================="
success_msg "MiniBlog MariaDB模式部署完成！"
echo "=========================================="

echo ""
echo "📋 部署信息:"
echo "   • 部署模式: MariaDB数据库（双容器）"
echo "   • 应用容器: miniblog-app-mariadb"
echo "   • 数据库容器: miniblog-mariadb"
echo "   • HTTP API: http://localhost:5555"
echo "   • gRPC API: localhost:6666"
echo "   • 数据库: localhost:3306"
echo "   • 健康检查: http://localhost:5555/healthz"

echo ""
echo "🔧 管理命令:"
echo "   • 查看应用日志: docker logs -f miniblog-app-mariadb"
echo "   • 查看数据库日志: docker logs -f miniblog-mariadb"
echo "   • 连接数据库: docker exec -it miniblog-mariadb mysql -u miniblog -pminiblog1234 miniblog"
echo "   • 停止服务: docker stop miniblog-app-mariadb miniblog-mariadb"
echo "   • 重启服务: docker restart miniblog-app-mariadb miniblog-mariadb"

echo ""
echo "📊 默认用户信息:"
echo "   • 用户名: root"
echo "   • 密码: miniblog1234 (已加密存储)"
echo "   • 用户ID: user-000000"

echo ""
echo "🧪 测试部署:"
echo "   • 运行测试: ./docker-deployment/scripts/test-deployment.sh mariadb"

echo ""
echo "📚 更多管理:"
echo "   • 服务管理: ./docker-deployment/scripts/manage.sh"

echo ""
info_msg "部署完成！你现在有一个完整的双容器MiniBlog系统运行在你的服务器上。"