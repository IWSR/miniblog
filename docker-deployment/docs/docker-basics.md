# Docker 基础知识

本文档介绍MiniBlog项目中涉及的Docker核心概念和知识点。

## 核心概念

### 1. 镜像 (Image)

**定义**: 镜像是容器的模板，包含了运行应用所需的所有文件、依赖和配置。

**特点**:

- 只读的
- 分层存储
- 可以复用

**在MiniBlog中的应用**:

```bash
# 构建MiniBlog镜像
docker build -t miniblog:latest .

# 查看镜像
docker images | grep miniblog

# 镜像分层
docker history miniblog:latest
```

### 2. 容器 (Container)

**定义**: 容器是镜像的运行实例，是一个隔离的运行环境。

**特点**:

- 可读写的
- 进程隔离
- 资源限制

**在MiniBlog中的应用**:

```bash
# 运行容器
docker run -d --name miniblog-app miniblog:latest

# 查看运行中的容器
docker ps

# 进入容器
docker exec -it miniblog-app /bin/sh
```

### 3. 网络 (Network)

**定义**: Docker网络让容器之间可以相互通信。

**网络类型**:

- bridge: 默认网络，容器间可通信
- host: 使用宿主机网络
- none: 无网络连接

**在MiniBlog中的应用**:

```bash
# 创建自定义网络
docker network create miniblog-network

# 容器加入网络
docker run --network miniblog-network miniblog:latest

# 容器间通信（通过容器名）
# 应用容器访问数据库: miniblog-mariadb:3306
```

### 4. 数据卷 (Volume)

**定义**: 数据卷用于持久化存储容器数据。

**类型**:

- 命名卷: `docker volume create volume-name`
- 绑定挂载: `-v /host/path:/container/path`
- 临时文件系统: `--tmpfs`

**在MiniBlog中的应用**:

```bash
# 创建数据卷
docker volume create miniblog-db-data

# 挂载数据卷
docker run -v miniblog-db-data:/var/lib/mysql mariadb

# 挂载配置文件
docker run -v /tmp/config.yaml:/opt/miniblog/config.yaml miniblog
```

## Dockerfile 详解

### MiniBlog的Dockerfile分析

```dockerfile
# 基础镜像选择
FROM alpine:3.18
# 选择轻量级的Alpine Linux，减少镜像大小

# 安装依赖
RUN apk add --no-cache tzdata ca-certificates
# tzdata: 时区数据
# ca-certificates: SSL证书

# 设置时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# 设置为中国时区

# 创建用户（安全最佳实践）
RUN addgroup -g 1000 miniblog && \
    adduser -D -s /bin/sh -u 1000 -G miniblog miniblog
# 避免使用root用户运行应用

# 创建目录
RUN mkdir -p /opt/miniblog/bin /opt/miniblog/configs /opt/miniblog/log
# 应用程序目录结构

# 复制程序
COPY mb-apiserver /opt/miniblog/bin/mb-apiserver
# 将编译好的程序复制到容器中

# 设置权限
RUN chmod +x /opt/miniblog/bin/mb-apiserver
# 给程序执行权限

# 切换用户
USER miniblog
# 以非root用户运行

# 工作目录
WORKDIR /opt/miniblog
# 设置工作目录

# 暴露端口
EXPOSE 5555 6666
# 声明容器监听的端口

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5555/healthz || exit 1
# 定期检查应用健康状态

# 启动命令
ENTRYPOINT ["/opt/miniblog/bin/mb-apiserver"]
# 容器启动时执行的命令
```

### Dockerfile最佳实践

1. **使用轻量级基础镜像**

   ```dockerfile
   FROM alpine:3.18  # 而不是 ubuntu:latest
   ```

2. **合并RUN指令**

   ```dockerfile
   RUN apk add --no-cache tzdata ca-certificates && \
       ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
   ```

3. **使用非root用户**

   ```dockerfile
   USER miniblog
   ```

4. **添加健康检查**

   ```dockerfile
   HEALTHCHECK CMD curl -f http://localhost:5555/healthz || exit 1
   ```

## Docker命令详解

### 镜像相关命令

```bash
# 构建镜像
docker build -t miniblog:latest .
# -t: 指定镜像名称和标签
# .: 构建上下文（当前目录）

# 查看镜像
docker images
docker images | grep miniblog

# 删除镜像
docker rmi miniblog:latest

# 导出镜像
docker save -o miniblog.tar miniblog:latest

# 导入镜像
docker load -i miniblog.tar

# 查看镜像历史
docker history miniblog:latest
```

### 容器相关命令

```bash
# 运行容器
docker run [选项] 镜像名 [命令]

# 常用选项：
# -d: 后台运行
# --name: 指定容器名称
# -p: 端口映射
# -v: 挂载卷
# -e: 设置环境变量
# --network: 指定网络
# --restart: 重启策略

# 示例
docker run -d \
  --name miniblog-app \
  -p 5555:5555 \
  -v /tmp/config.yaml:/opt/miniblog/config.yaml \
  -e ENV=production \
  --network miniblog-network \
  --restart unless-stopped \
  miniblog:latest

# 查看容器
docker ps          # 运行中的容器
docker ps -a       # 所有容器

# 容器操作
docker start container-name    # 启动
docker stop container-name     # 停止
docker restart container-name  # 重启
docker rm container-name       # 删除

# 进入容器
docker exec -it container-name /bin/sh

# 查看日志
docker logs container-name
docker logs -f container-name  # 实时查看

# 查看容器详情
docker inspect container-name

# 查看资源使用
docker stats container-name
```

### 网络相关命令

```bash
# 创建网络
docker network create network-name

# 查看网络
docker network ls
docker network inspect network-name

# 连接容器到网络
docker network connect network-name container-name

# 断开网络连接
docker network disconnect network-name container-name

# 删除网络
docker network rm network-name
```

### 数据卷相关命令

```bash
# 创建数据卷
docker volume create volume-name

# 查看数据卷
docker volume ls
docker volume inspect volume-name

# 删除数据卷
docker volume rm volume-name

# 清理未使用的数据卷
docker volume prune
```

## 端口映射详解

### 端口映射语法

```bash
-p [宿主机IP:]宿主机端口:容器端口[/协议]
```

### 示例

```bash
# 基本映射
-p 5555:5555          # 宿主机5555端口映射到容器5555端口

# 指定IP
-p 127.0.0.1:5555:5555  # 只允许本地访问

# 指定协议
-p 5555:5555/tcp      # TCP协议（默认）
-p 6666:6666/udp      # UDP协议

# 动态端口
-p 5555               # 宿主机随机端口映射到容器5555端口

# 多端口映射
-p 5555:5555 -p 6666:6666
```

### MiniBlog端口配置

```bash
# HTTP API端口
-p 5555:5555

# gRPC API端口
-p 6666:6666

# MariaDB数据库端口
-p 3306:3306
```

## 环境变量

### 设置环境变量

```bash
# 单个环境变量
-e KEY=VALUE

# 多个环境变量
-e KEY1=VALUE1 -e KEY2=VALUE2

# 从文件读取
--env-file .env
```

### MiniBlog环境变量示例

```bash
# MariaDB容器环境变量
-e MYSQL_ROOT_PASSWORD=root123456
-e MYSQL_DATABASE=miniblog
-e MYSQL_USER=miniblog
-e MYSQL_PASSWORD=miniblog1234

# 应用容器环境变量
-e ENV=production
-e LOG_LEVEL=info
```

## 容器间通信

### 同一网络内通信

```bash
# 创建网络
docker network create miniblog-network

# 启动数据库容器
docker run -d --name miniblog-mariadb --network miniblog-network mariadb

# 启动应用容器
docker run -d --name miniblog-app --network miniblog-network miniblog

# 应用容器中访问数据库
# 主机名: miniblog-mariadb
# 端口: 3306
# 连接字符串: miniblog-mariadb:3306
```

### 网络隔离

- 不同网络中的容器无法直接通信
- 提供了安全隔离
- 可以通过端口映射暴露服务

## 数据持久化

### 数据卷挂载

```bash
# 命名卷（推荐）
-v volume-name:/container/path

# 绑定挂载
-v /host/path:/container/path

# 只读挂载
-v /host/path:/container/path:ro
```

### MiniBlog数据持久化

```bash
# 数据库数据持久化
-v miniblog-db-data:/var/lib/mysql

# 配置文件挂载
-v /tmp/config.yaml:/opt/miniblog/config.yaml

# 日志目录挂载
-v /var/log/miniblog:/opt/miniblog/log
```

## 重启策略

### 重启策略选项

```bash
--restart no          # 不自动重启（默认）
--restart on-failure  # 失败时重启
--restart always      # 总是重启
--restart unless-stopped  # 除非手动停止，否则总是重启
```

### MiniBlog重启策略

```bash
# 推荐使用 unless-stopped
--restart unless-stopped
```

## 资源限制

### CPU限制

```bash
--cpus="1.5"          # 限制使用1.5个CPU核心
--cpu-shares=1024     # CPU权重
```

### 内存限制

```bash
-m 512m               # 限制内存使用512MB
--memory=512m         # 同上
```

### MiniBlog资源限制示例

```bash
docker run -d \
  --name miniblog-app \
  --cpus="0.5" \
  -m 256m \
  miniblog:latest
```

## 日志管理

### 查看日志

```bash
docker logs container-name
docker logs -f container-name        # 实时查看
docker logs --tail 100 container-name  # 最后100行
docker logs --since 2023-01-01 container-name  # 指定时间后的日志
```

### 日志驱动

```bash
--log-driver json-file    # 默认，JSON格式
--log-driver syslog       # 系统日志
--log-driver none         # 不记录日志
```

### 日志选项

```bash
--log-opt max-size=10m    # 单个日志文件最大10MB
--log-opt max-file=3      # 最多保留3个日志文件
```

## 健康检查

### 健康检查配置

```dockerfile
HEALTHCHECK [选项] CMD 命令
```

### 选项说明

- `--interval=30s`: 检查间隔
- `--timeout=3s`: 超时时间
- `--start-period=5s`: 启动等待时间
- `--retries=3`: 重试次数

### MiniBlog健康检查

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5555/healthz || exit 1
```

### 查看健康状态

```bash
docker ps  # STATUS列显示健康状态
docker inspect container-name | grep Health
```

这些Docker基础知识涵盖了MiniBlog项目中使用的所有核心概念，帮助你更好地理解和管理Docker容器。
