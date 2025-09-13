#!/bin/bash

# 从GitHub Container Registry部署MiniBlog

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

# 默认配置
DEFAULT_REGISTRY="ghcr.io"
DEFAULT_REPO="onexstack/miniblog"  # 替换为你的GitHub用户名/仓库名
DEFAULT_TAG="latest"
DEFAULT_MODE="mariadb"

# 解析命令行参数
show_help() {
    echo "从GitHub Container Registry部署MiniBlog"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -r, --registry REGISTRY   容器注册表 (默认: $DEFAULT_REGISTRY)"
    echo "  -i, --image IMAGE         镜像名称 (默认: $DEFAULT_REPO)"
    echo "  -t, --tag TAG            镜像标签 (默认: $DEFAULT_TAG)"
    echo "  -m, --mode MODE          部署模式: memory|mariadb (默认: $DEFAULT_MODE)"
    echo "  -h, --help               显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认配置"
    echo "  $0 -t v1.0.0 -m memory              # 部署v1.0.0版本，内存模式"
    echo "  $0 -i myuser/miniblog -t latest     # 使用自定义镜像"
    echo ""
}

# 解析参数
REGISTRY="$DEFAULT_REGISTRY"
IMAGE_REPO="$DEFAULT_REPO"
TAG="$DEFAULT_TAG"
MODE="$DEFAULT_MODE"

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_REPO="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 构建完整镜像名
FULL_IMAGE="$REGISTRY/$IMAGE_REPO:$TAG"

echo "=========================================="
echo "  从GitHub部署MiniBlog"
echo "=========================================="

info_msg "部署配置:"
echo "  镜像: $FULL_IMAGE"
echo "  模式: $MODE"
echo ""

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    error_exit "Docker未安装，请先安装Docker"
fi

# 检查模式参数
if [[ "$MODE" != "memory" && "$MODE" != "mariadb" ]]; then
    error_exit "无效的部署模式: $MODE (支持: memory, mariadb)"
fi

echo "第1步：拉取Docker镜像"
info_msg "正在拉取镜像: $FULL_IMAGE"

# 如果是GitHub Container Registry，可能需要登录
if [[ "$REGISTRY" == "ghcr.io" ]]; then
    warning_msg "如果镜像是私有的，请先登录GitHub Container Registry:"
    echo "  echo \$GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
    echo ""
fi

if ! docker pull "$FULL_IMAGE"; then
    error_exit "镜像拉取失败，请检查镜像名称和网络连接"
fi

success_msg "镜像拉取成功"

echo ""
echo "第2步：清理旧容器"
if [[ "$MODE" == "mariadb" ]]; then
    docker stop miniblog-app-github miniblog-mariadb 2>/dev/null || true
    docker rm miniblog-app-github miniblog-mariadb 2>/dev/null || true
else
    docker stop miniblog-github 2>/dev/null || true
    docker rm miniblog-github 2>/dev/null || true
fi
success_msg "旧容器清理完成"

echo ""
if [[ "$MODE" == "mariadb" ]]; then
    echo "第3步：部署MariaDB模式"
    
    # 创建网络
    docker network create miniblog-network 2>/dev/null || true
    success_msg "Docker网络已创建"
    
    # 启动MariaDB
    info_msg "启动MariaDB容器..."
    docker run -d \
      --name miniblog-mariadb \
      --network miniblog-network \
      -e MYSQL_ROOT_PASSWORD=root123456 \
      -e MYSQL_DATABASE=miniblog \
      -e MYSQL_USER=miniblog \
      -e MYSQL_PASSWORD=miniblog1234 \
      -p 3306:3306 \
      -v miniblog-db-data:/var/lib/mysql \
      --restart unless-stopped \
      mariadb:10.11
    
    success_msg "MariaDB容器启动成功"
    
    # 等待数据库启动
    info_msg "等待数据库初始化..."
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
    
    # 创建配置文件
    CONFIG_DIR="/tmp/miniblog-github-config"
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/mb-apiserver.yaml" << 'EOF'
server-mode: grpc-gateway
jwt-key: Rtg8BPKNEf2mB4mgvKONGPZZQSaJWNLijxR42qRgq0iBb5
expiration: 2h
enable-memory-store: false
tls:
  use-tls: false
http:
  addr: :5555
grpc:
  addr: :6666
mysql:
  addr: miniblog-mariadb:3306
  username: miniblog
  password: miniblog1234
  database: miniblog
  max-idle-connections: 50
  max-open-connections: 100
  max-connection-life-time: 10s
  log-level: 2
log:
  disable-caller: false
  disable-stacktrace: false
  level: info
  format: json
  output-paths: [stdout]
EOF
    
    success_msg "配置文件已创建"
    
    # 启动应用容器
    info_msg "启动应用容器..."
    docker run -d \
      --name miniblog-app-github \
      --network miniblog-network \
      -p 5555:5555 \
      -p 6666:6666 \
      -v "$CONFIG_DIR/mb-apiserver.yaml:/opt/miniblog/configs/mb-apiserver.yaml" \
      --restart unless-stopped \
      "$FULL_IMAGE" \
      --config=/opt/miniblog/configs/mb-apiserver.yaml
    
    success_msg "应用容器启动成功"
    
else
    echo "第3步：部署内存数据库模式"
    
    # 创建配置文件
    CONFIG_DIR="/tmp/miniblog-github-config"
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/mb-apiserver.yaml" << 'EOF'
server-mode: grpc-gateway
jwt-key: Rtg8BPKNEf2mB4mgvKONGPZZQSaJWNLijxR42qRgq0iBb5
expiration: 2h
enable-memory-store: true
tls:
  use-tls: false
http:
  addr: :5555
grpc:
  addr: :6666
log:
  disable-caller: false
  disable-stacktrace: false
  level: info
  format: json
  output-paths: [stdout]
EOF
    
    success_msg "配置文件已创建"
    
    # 启动应用容器
    info_msg "启动应用容器..."
    docker run -d \
      --name miniblog-github \
      -p 5555:5555 \
      -p 6666:6666 \
      -v "$CONFIG_DIR/mb-apiserver.yaml:/opt/miniblog/configs/mb-apiserver.yaml" \
      --restart unless-stopped \
      "$FULL_IMAGE" \
      --config=/opt/miniblog/configs/mb-apiserver.yaml
    
    success_msg "应用容器启动成功"
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
# 健康检查
HEALTH_RESPONSE=$(curl -s http://localhost:5555/healthz)
if [ $? -eq 0 ]; then
    success_msg "健康检查通过: $HEALTH_RESPONSE"
else
    warning_msg "健康检查失败，请检查应用日志"
fi

# 显示容器状态
echo ""
echo "容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep miniblog

echo ""
echo "=========================================="
success_msg "MiniBlog GitHub部署完成！"
echo "=========================================="

echo ""
echo "📋 部署信息:"
echo "   • 镜像: $FULL_IMAGE"
echo "   • 模式: $MODE"
echo "   • HTTP API: http://localhost:5555"
echo "   • gRPC API: localhost:6666"
echo "   • 健康检查: http://localhost:5555/healthz"

echo ""
echo "🔧 管理命令:"
if [[ "$MODE" == "mariadb" ]]; then
    echo "   • 查看应用日志: docker logs -f miniblog-app-github"
    echo "   • 查看数据库日志: docker logs -f miniblog-mariadb"
    echo "   • 连接数据库: docker exec -it miniblog-mariadb mysql -u miniblog -pminiblog1234 miniblog"
    echo "   • 停止服务: docker stop miniblog-app-github miniblog-mariadb"
else
    echo "   • 查看日志: docker logs -f miniblog-github"
    echo "   • 停止服务: docker stop miniblog-github"
fi

echo ""
echo "📊 默认用户信息:"
echo "   • 用户名: root"
echo "   • 密码: miniblog1234"

echo ""
info_msg "部署完成！你现在运行的是从GitHub自动构建的MiniBlog镜像。"