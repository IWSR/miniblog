#!/bin/bash

# 不使用 set -e，手动处理关键错误

# 获取镜像标签参数
IMAGE_TAG=${1:-"latest"}
CONTAINER_NAME="miniblog"
DB_CONTAINER="miniblog-mariadb"
NETWORK_NAME="miniblog-network"
PORT=${PORT:-8080}

echo "🚀 开始生产环境部署..."
echo "镜像: $IMAGE_TAG"

# 显示当前状态
echo "📋 当前Docker状态:"
docker ps -a | grep miniblog || echo "ℹ️  当前没有 miniblog 容器"
docker images | grep miniblog || echo "ℹ️  当前没有 miniblog 镜像"

# 创建Docker网络（如果不存在）
echo "🌐 创建Docker网络..."
docker network create $NETWORK_NAME 2>/dev/null || echo "ℹ️  网络已存在"

# 检查MariaDB镜像是否存在，如果不存在则尝试多种方式获取
echo "🔍 检查MariaDB镜像..."
if ! docker images | grep -q "mariadb"; then
    echo "� Ma删riaDB镜像不存在，尝试拉取..."
    
    # 尝试多个镜像源和版本
    MARIADB_IMAGES=(
        "mariadb:10.11"
        "mariadb:10.6"
        "mariadb:latest"
        "mysql:8.0"
        "mysql:5.7"
    )
    
    PULLED_IMAGE=""
    for img in "${MARIADB_IMAGES[@]}"; do
        echo "🔄 尝试拉取: $img"
        if timeout 300 docker pull "$img"; then
            echo "✅ 成功拉取: $img"
            PULLED_IMAGE="$img"
            break
        else
            echo "❌ 拉取失败: $img"
        fi
    done
    
    if [ -z "$PULLED_IMAGE" ]; then
        echo "❌ 所有数据库镜像拉取都失败了"
        echo "🔧 尝试手动解决方案..."
        
        # 检查是否有任何MySQL/MariaDB相关镜像
        EXISTING_DB_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(mysql|mariadb)" | head -1)
        if [ ! -z "$EXISTING_DB_IMAGE" ]; then
            echo "✅ 发现现有数据库镜像: $EXISTING_DB_IMAGE"
            PULLED_IMAGE="$EXISTING_DB_IMAGE"
        else
            echo "❌ 无法获取任何数据库镜像，部署失败"
            echo "💡 建议手动执行: docker pull mariadb:latest"
            exit 1
        fi
    fi
else
    # 使用现有的MariaDB镜像
    PULLED_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep mariadb | head -1)
    if [ -z "$PULLED_IMAGE" ]; then
        PULLED_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep mysql | head -1)
    fi
    echo "✅ 使用现有镜像: $PULLED_IMAGE"
fi

# 启动MariaDB容器
if ! docker ps --format "{{.Names}}" | grep -q "^${DB_CONTAINER}$"; then
    echo "🗄️  启动MariaDB容器..."
    
    # 先清理可能存在的同名容器
    docker rm -f $DB_CONTAINER 2>/dev/null || true
    
    # 根据镜像类型设置不同的环境变量
    if echo "$PULLED_IMAGE" | grep -q "mysql"; then
        # MySQL镜像
        ENV_VARS="-e MYSQL_ROOT_PASSWORD=root123456 -e MYSQL_DATABASE=miniblog -e MYSQL_USER=miniblog -e MYSQL_PASSWORD=miniblog1234"
    else
        # MariaDB镜像
        ENV_VARS="-e MYSQL_ROOT_PASSWORD=root123456 -e MYSQL_DATABASE=miniblog -e MYSQL_USER=miniblog -e MYSQL_PASSWORD=miniblog1234"
    fi
    
    # 启动数据库容器
    echo "🚀 启动数据库容器: $PULLED_IMAGE"
    if docker run -d \
        --name $DB_CONTAINER \
        --network $NETWORK_NAME \
        $ENV_VARS \
        -p 3306:3306 \
        -v miniblog-db-data:/var/lib/mysql \
        --restart unless-stopped \
        $PULLED_IMAGE; then
        echo "✅ 数据库容器启动成功"
    else
        echo "❌ 数据库容器启动失败"
        exit 1
    fi
    
    echo "⏳ 等待数据库启动..."
    sleep 15
    
    # 检查容器是否成功启动
    if ! docker ps --format "{{.Names}}" | grep -q "^${DB_CONTAINER}$"; then
        echo "❌ 数据库容器启动失败"
        docker logs $DB_CONTAINER
        exit 1
    fi
    
    # 等待数据库服务就绪
    echo "🔍 等待数据库服务就绪..."
    for i in {1..180}; do
        if docker exec $DB_CONTAINER mysqladmin ping -h localhost -u root -proot123456 --silent 2>/dev/null; then
            echo "✅ 数据库服务已就绪"
            
            # 初始化数据库表结构（仅在首次启动时）
            echo "📝 检查数据库表结构..."
            TABLE_COUNT=$(docker exec $DB_CONTAINER mysql -u root -proot123456 -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='miniblog';" -s -N 2>/dev/null || echo "0")
            if [ "$TABLE_COUNT" -eq "0" ]; then
                echo "📝 初始化数据库表结构..."
                # 下载SQL文件并初始化
                if curl -fsSL https://raw.githubusercontent.com/IWSR/miniblog/master/configs/miniblog.sql -o /tmp/miniblog.sql; then
                    docker exec -i $DB_CONTAINER mysql -u root -proot123456 < /tmp/miniblog.sql
                    echo "✅ 数据库初始化完成"
                else
                    echo "⚠️  无法下载SQL文件，跳过初始化"
                fi
            else
                echo "✅ 数据库表结构已存在，跳过初始化"
            fi
            break
        fi
        if [ $i -eq 180 ]; then
            echo "❌ 数据库服务启动超时"
            echo "📋 数据库容器日志:"
            docker logs --tail 20 $DB_CONTAINER
            exit 1
        fi
        echo "⏳ 等待数据库服务响应... ($i/180)"
        sleep 2
    done
else
    echo "✅ MariaDB容器已存在并运行中"
fi

# 停止并删除现有应用容器（如果存在）
RUNNING_CONTAINER=$(docker ps -q -f name=$CONTAINER_NAME)
if [ ! -z "$RUNNING_CONTAINER" ]; then
    echo "🔄 停止现有应用容器..."
    docker stop $CONTAINER_NAME || echo "⚠️  停止容器失败，继续执行"
fi

EXISTING_CONTAINER=$(docker ps -aq -f name=$CONTAINER_NAME)
if [ ! -z "$EXISTING_CONTAINER" ]; then
    echo "🗑️  删除现有应用容器..."
    docker rm $CONTAINER_NAME || echo "⚠️  删除容器失败，继续执行"
fi

# 拉取最新应用镜像
echo "📥 拉取应用镜像: $IMAGE_TAG"
if docker pull "$IMAGE_TAG"; then
    echo "✅ 应用镜像拉取成功"
else
    echo "❌ 应用镜像拉取失败"
    exit 1
fi

# 创建应用配置文件（数据库模式）
echo "📝 创建应用配置文件（数据库模式）..."
cat > /tmp/mb-apiserver.yaml << 'EOF'
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

# 启动新的应用容器
echo "🚀 启动应用容器..."
if docker run -d \
    --name $CONTAINER_NAME \
    --network $NETWORK_NAME \
    --restart unless-stopped \
    -p $PORT:5555 \
    -v /tmp/mb-apiserver.yaml:/opt/miniblog/mb-apiserver.yaml \
    $IMAGE_TAG \
    --config=/opt/miniblog/mb-apiserver.yaml; then
    echo "✅ 应用容器启动成功"
else
    echo "❌ 应用容器启动失败"
    exit 1
fi

# 等待容器启动
echo "⏳ 等待应用容器启动..."
sleep 5

# 检查容器状态
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✅ 应用容器启动成功"
    
    # 显示容器信息
    echo "📊 容器信息:"
    echo "--- 应用容器 ---"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | head -1
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep $CONTAINER_NAME
    echo "--- 数据库容器 ---"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep $DB_CONTAINER
    
    # 健康检查
    echo "🔍 执行应用健康检查..."
    sleep 3
    for i in {1..10}; do
        if curl -f http://localhost:$PORT >/dev/null 2>&1; then
            echo "✅ 应用健康检查通过"
            echo "🌐 应用访问地址: http://localhost:$PORT"
            break
        fi
        if [ $i -eq 10 ]; then
            echo "⚠️  健康检查未通过，但容器已启动"
            echo "📋 应用容器日志:"
            docker logs --tail 10 $CONTAINER_NAME
        else
            echo "⏳ 等待应用响应... ($i/10)"
            sleep 3
        fi
    done
    
    echo "🎉 完整部署完成!"
    echo "📊 部署摘要:"
    echo "  - 数据库: $PULLED_IMAGE (端口 3306)"
    echo "  - 应用: miniblog (端口 $PORT)"
    echo "  - 网络: $NETWORK_NAME"
    echo "  - 数据持久化: ✅"
else
    echo "❌ 应用容器启动失败"
    echo "📋 容器日志:"
    docker logs $CONTAINER_NAME 2>/dev/null || echo "无法获取容器日志"
    exit 1
fi