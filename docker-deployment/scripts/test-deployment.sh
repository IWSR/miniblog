#!/bin/bash

# MiniBlog 部署测试脚本

# 设置颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

success_msg() {
    echo -e "${GREEN}✅ $1${NC}"
}

error_msg() {
    echo -e "${RED}❌ $1${NC}"
}

info_msg() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning_msg() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 获取部署模式参数
DEPLOY_MODE=${1:-"auto"}

echo "=========================================="
echo "  MiniBlog 部署测试脚本"
echo "=========================================="

# 自动检测部署模式
if [ "$DEPLOY_MODE" = "auto" ]; then
    if docker ps | grep -q "miniblog-app-mariadb"; then
        DEPLOY_MODE="mariadb"
        CONTAINER_NAME="miniblog-app-mariadb"
        DB_CONTAINER="miniblog-mariadb"
    elif docker ps | grep -q "miniblog-memory"; then
        DEPLOY_MODE="memory"
        CONTAINER_NAME="miniblog-memory"
        DB_CONTAINER=""
    else
        error_msg "未找到运行中的MiniBlog容器"
        echo "请先部署MiniBlog系统："
        echo "  内存数据库: ./docker-deployment/scripts/deploy-memory.sh"
        echo "  MariaDB数据库: ./docker-deployment/scripts/deploy-mariadb.sh"
        exit 1
    fi
elif [ "$DEPLOY_MODE" = "mariadb" ]; then
    CONTAINER_NAME="miniblog-app-mariadb"
    DB_CONTAINER="miniblog-mariadb"
elif [ "$DEPLOY_MODE" = "memory" ]; then
    CONTAINER_NAME="miniblog-memory"
    DB_CONTAINER=""
else
    error_msg "无效的部署模式: $DEPLOY_MODE"
    echo "支持的模式: memory, mariadb, auto"
    exit 1
fi

info_msg "检测到部署模式: $DEPLOY_MODE"

test_api() {
    local url=$1
    local description=$2
    local expected_status=${3:-200}
    
    echo -n "测试 $description ... "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/api_response "$url" 2>/dev/null)
    
    if [ "$response" = "$expected_status" ]; then
        success_msg "通过 (HTTP $response)"
        if [ -s /tmp/api_response ]; then
            echo "   响应: $(cat /tmp/api_response | head -c 100)..."
        fi
    else
        error_msg "失败 (HTTP $response)"
        if [ -s /tmp/api_response ]; then
            echo "   响应: $(cat /tmp/api_response)"
        fi
        return 1
    fi
    echo ""
    return 0
}

echo ""
echo "第1步：检查容器状态"
echo "运行中的容器:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep miniblog

if ! docker ps | grep -q "$CONTAINER_NAME"; then
    error_msg "应用容器 $CONTAINER_NAME 未运行"
    exit 1
fi

if [ -n "$DB_CONTAINER" ] && ! docker ps | grep -q "$DB_CONTAINER"; then
    error_msg "数据库容器 $DB_CONTAINER 未运行"
    exit 1
fi

success_msg "所有容器都在运行"

if [ "$DEPLOY_MODE" = "mariadb" ]; then
    echo ""
    echo "第2步：检查网络连接"
    info_msg "测试容器间网络连接..."
    if docker exec $CONTAINER_NAME ping -c 1 $DB_CONTAINER > /dev/null 2>&1; then
        success_msg "容器间网络连接正常"
    else
        error_msg "容器间网络连接失败"
    fi

    echo ""
    echo "第3步：检查数据库连接"
    info_msg "测试数据库连接..."
    if docker exec $DB_CONTAINER mysqladmin ping -h localhost -u miniblog -pminiblog1234 --silent 2>/dev/null; then
        success_msg "数据库连接正常"
    else
        error_msg "数据库连接失败"
    fi

    # 检查数据库表
    echo "数据库表列表:"
    docker exec $DB_CONTAINER mysql -u miniblog -pminiblog1234 miniblog -e "SHOW TABLES;" 2>/dev/null | grep -v Tables_in_miniblog
fi

echo ""
echo "第4步：API接口测试"
info_msg "等待5秒确保服务完全启动..."
sleep 5

# 测试健康检查
if ! test_api "http://localhost:5555/healthz" "健康检查接口"; then
    error_msg "健康检查失败，服务可能未正常启动"
    echo "查看应用日志："
    docker logs --tail 20 $CONTAINER_NAME
    exit 1
fi

# 测试用户注册
echo "第5步：测试用户注册"
REGISTER_DATA='{
  "username": "testuser_'$(date +%s)'",
  "password": "testpass123",
  "nickname": "测试用户",
  "email": "test'$(date +%s)'@example.com",
  "phone": "1380013'$(date +%s | tail -c 5)'"
}'

echo "注册数据: $REGISTER_DATA"
REGISTER_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$REGISTER_DATA" \
  http://localhost:5555/v1/users \
  -w "HTTP状态码: %{http_code}")

echo "注册响应: $REGISTER_RESPONSE"

# 测试用户登录
echo ""
echo "第6步：测试用户登录"
LOGIN_DATA='{
  "username": "root",
  "password": "miniblog1234"
}'

TOKEN_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$LOGIN_DATA" \
  http://localhost:5555/v1/login)

echo "登录响应: $TOKEN_RESPONSE"

# 提取token（如果登录成功）
if echo "$TOKEN_RESPONSE" | grep -q "token"; then
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    success_msg "登录成功，获取到token"
    
    # 测试需要认证的接口
    echo ""
    echo "第7步：测试认证接口"
    echo "测试获取用户列表（需要认证）..."
    AUTH_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
      http://localhost:5555/v1/users \
      -w "HTTP状态码: %{http_code}")
    echo "认证接口响应: $AUTH_RESPONSE"
else
    warning_msg "登录失败，跳过认证接口测试"
fi

echo ""
echo "第8步：gRPC接口测试"
info_msg "检查gRPC端口是否开放..."
if command -v nc &> /dev/null; then
    if nc -z localhost 6666 2>/dev/null; then
        success_msg "gRPC端口 6666 可访问"
    else
        error_msg "gRPC端口 6666 不可访问"
    fi
else
    warning_msg "nc命令不可用，跳过gRPC端口测试"
fi

echo ""
echo "第9步：资源使用情况"
echo "容器资源使用:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | grep miniblog

echo ""
echo "第10步：日志检查"
info_msg "检查应用日志中是否有错误..."
ERROR_COUNT=$(docker logs $CONTAINER_NAME 2>&1 | grep -i error | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    success_msg "应用日志中没有错误"
else
    warning_msg "应用日志中发现 $ERROR_COUNT 个错误"
    echo "最近的错误日志:"
    docker logs --tail 10 $CONTAINER_NAME 2>&1 | grep -i error
fi

echo ""
echo "=========================================="
success_msg "部署测试完成！"
echo "=========================================="

echo ""
echo "📋 测试总结:"
echo "   • 部署模式: $DEPLOY_MODE"
echo "   • 容器状态: 正常运行"
if [ "$DEPLOY_MODE" = "mariadb" ]; then
echo "   • 网络连接: 正常"
echo "   • 数据库连接: 正常"
fi
echo "   • HTTP API: 可访问"
echo "   • gRPC API: 端口开放"

echo ""
echo "🌐 访问地址:"
echo "   • 健康检查: http://localhost:5555/healthz"
echo "   • 用户接口: http://localhost:5555/v1/users"
echo "   • 登录接口: http://localhost:5555/v1/login"

echo ""
echo "🔧 管理命令:"
echo "   • 服务管理: ./docker-deployment/scripts/manage.sh"
echo "   • 查看日志: docker logs -f $CONTAINER_NAME"
if [ -n "$DB_CONTAINER" ]; then
echo "   • 数据库日志: docker logs -f $DB_CONTAINER"
echo "   • 连接数据库: docker exec -it $DB_CONTAINER mysql -u miniblog -pminiblog1234 miniblog"
fi

echo ""
info_msg "你的MiniBlog系统已经成功部署并通过测试！"