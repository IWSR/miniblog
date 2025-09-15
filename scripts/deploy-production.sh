#!/bin/bash

# 不使用 set -e，手动处理关键错误

# 获取镜像标签参数
IMAGE_TAG=${1:-"latest"}
CONTAINER_NAME="miniblog"
PORT=${PORT:-8080}

echo "🚀 开始生产环境部署..."
echo "镜像: $IMAGE_TAG"

# 显示当前状态
echo "📋 当前Docker状态:"
docker ps -a | grep miniblog || echo "ℹ️  当前没有 miniblog 容器"
docker images | grep miniblog || echo "ℹ️  当前没有 miniblog 镜像"

# 停止并删除现有容器（如果存在）
RUNNING_CONTAINER=$(docker ps -q -f name=$CONTAINER_NAME)
if [ ! -z "$RUNNING_CONTAINER" ]; then
    echo "🔄 停止现有容器..."
    docker stop $CONTAINER_NAME || echo "⚠️  停止容器失败，继续执行"
fi

EXISTING_CONTAINER=$(docker ps -aq -f name=$CONTAINER_NAME)
if [ ! -z "$EXISTING_CONTAINER" ]; then
    echo "🗑️  删除现有容器..."
    docker rm $CONTAINER_NAME || echo "⚠️  删除容器失败，继续执行"
fi

# 拉取最新镜像
echo "📥 拉取镜像: $IMAGE_TAG"
if docker pull "$IMAGE_TAG"; then
    echo "✅ 镜像拉取成功"
else
    echo "❌ 镜像拉取失败"
    exit 1
fi

# 启动新容器
echo "🚀 启动新容器..."
if docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -p $PORT:8080 \
    $IMAGE_TAG; then
    echo "✅ 容器启动命令执行成功"
else
    echo "❌ 容器启动失败"
    exit 1
fi

# 等待容器启动
echo "⏳ 等待容器启动..."
sleep 3

# 检查容器状态
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✅ 容器启动成功"
    
    # 显示容器信息
    echo "📊 容器信息:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | head -1
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep $CONTAINER_NAME
    
    # 简单健康检查
    echo "🔍 执行健康检查..."
    sleep 2
    if curl -f http://localhost:$PORT >/dev/null 2>&1; then
        echo "✅ 应用健康检查通过"
        echo "🌐 应用访问地址: http://localhost:$PORT"
    else
        echo "⚠️  健康检查未通过，但容器已启动"
        echo "📋 容器日志:"
        docker logs --tail 5 $CONTAINER_NAME
    fi
    
    echo "🎉 部署完成!"
else
    echo "❌ 容器启动失败"
    echo "📋 容器日志:"
    docker logs $CONTAINER_NAME 2>/dev/null || echo "无法获取容器日志"
    exit 1
fi