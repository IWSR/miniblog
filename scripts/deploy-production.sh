#!/bin/bash

set -e  # 遇到错误立即退出

# 获取镜像标签参数
IMAGE_TAG=${1:-"latest"}
CONTAINER_NAME="miniblog"
PORT=${PORT:-8080}

echo "🚀 开始生产环境部署..."
echo "镜像: $IMAGE_TAG"

# 显示当前镜像列表
echo "📋 当前镜像列表:"
docker images | grep miniblog || echo "ℹ️  当前没有 miniblog 镜像"

# 备份当前运行的容器（如果存在）
if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
    echo "🔄 停止现有容器..."
    docker stop $CONTAINER_NAME
    echo "🗑️  删除现有容器..."
    docker rm $CONTAINER_NAME
else
    echo "ℹ️  当前没有运行的容器，跳过停止步骤"
fi

# 拉取最新镜像
echo "📥 拉取最新镜像..."
if docker pull "$IMAGE_TAG"; then
    echo "✅ 镜像拉取成功"
else
    echo "❌ 镜像拉取失败"
    exit 1
fi

# 启动新容器
echo "🚀 启动新容器..."
docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -p $PORT:8080 \
    $IMAGE_TAG

# 等待容器启动
echo "⏳ 等待容器启动..."
sleep 5

# 检查容器状态
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✅ 容器启动成功"
    
    # 显示容器信息
    echo "📊 容器信息:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep $CONTAINER_NAME
    
    # 健康检查
    echo "🔍 执行健康检查..."
    for i in {1..12}; do
        if curl -f http://localhost:$PORT >/dev/null 2>&1; then
            echo "✅ 应用健康检查通过"
            echo "🌐 应用访问地址: http://localhost:$PORT"
            break
        fi
        if [ $i -eq 12 ]; then
            echo "⚠️  健康检查超时，但容器已启动"
            echo "📋 容器日志:"
            docker logs --tail 10 $CONTAINER_NAME
        else
            echo "⏳ 等待应用响应... ($i/12)"
            sleep 5
        fi
    done
    
    echo "🎉 部署完成!"
else
    echo "❌ 容器启动失败"
    echo "📋 容器日志:"
    docker logs $CONTAINER_NAME 2>/dev/null || echo "无法获取容器日志"
    exit 1
fi