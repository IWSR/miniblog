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
echo "🔍 调试信息:"
echo "  - 镜像标签: $IMAGE_TAG"
echo "  - Docker版本: $(docker --version)"
echo "  - 测试网络连接到 ghcr.io..."

# 测试网络连接
if curl -s --connect-timeout 10 https://ghcr.io >/dev/null; then
    echo "  ✅ 网络连接正常"
else
    echo "  ❌ 网络连接失败"
fi

# 拉取镜像（带重试机制）
echo "📥 开始拉取镜像: $IMAGE_TAG"

# 重试拉取镜像
PULL_SUCCESS=false
for attempt in {1..3}; do
    echo "🔄 拉取尝试 $attempt/3..."
    
    # 设置超时并拉取镜像
    timeout 1200 docker pull "$IMAGE_TAG" 2>&1 | tee /tmp/docker_pull_$attempt.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✅ 镜像拉取成功 (尝试 $attempt)"
        PULL_SUCCESS=true
        break
    else
        echo "❌ 拉取尝试 $attempt 失败"
        if [ $attempt -lt 3 ]; then
            echo "⏳ 等待 30 秒后重试..."
            sleep 30
        fi
    fi
done

if [ "$PULL_SUCCESS" = true ]; then
    echo "📋 拉取后的镜像信息:"
    docker images | grep miniblog
else
    echo "❌ 所有拉取尝试都失败了"
    echo "🔍 详细错误信息:"
    for i in {1..3}; do
        if [ -f "/tmp/docker_pull_$i.log" ]; then
            echo "--- 尝试 $i 的日志 ---"
            tail -10 /tmp/docker_pull_$i.log
        fi
    done
    
    echo "🔍 可能的原因:"
    echo "  1. 网络速度太慢，超过20分钟超时"
    echo "  2. 镜像体积过大"
    echo "  3. 服务器资源不足"
    echo "  4. GitHub Container Registry 限流"
    
    # 尝试拉取 latest 标签作为备选
    echo "🔄 尝试拉取 latest 标签作为备选..."
    FALLBACK_TAG=$(echo "$IMAGE_TAG" | sed 's/:.*/:latest/')
    if [ "$FALLBACK_TAG" != "$IMAGE_TAG" ]; then
        timeout 600 docker pull "$FALLBACK_TAG" && PULL_SUCCESS=true || echo "备选镜像也拉取失败"
    fi
    
    if [ "$PULL_SUCCESS" != true ]; then
        exit 1
    else
        IMAGE_TAG="$FALLBACK_TAG"
        echo "✅ 使用备选镜像: $IMAGE_TAG"
    fi
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