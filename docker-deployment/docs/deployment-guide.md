# MiniBlog Docker 部署完整指南

## 概述

本指南详细介绍如何在2C4G服务器上使用Docker部署MiniBlog系统。

## 系统架构

### 内存数据库模式（单容器）

```
┌─────────────────────────────┐
│      MiniBlog 应用容器       │
│    ┌─────────────────────┐   │
│    │   Go 应用程序        │   │
│    │   端口: 5555, 6666  │   │
│    └─────────────────────┘   │
│    ┌─────────────────────┐   │
│    │   内存数据库         │   │
│    │   (SQLite in memory)│   │
│    └─────────────────────┘   │
└─────────────────────────────┘
```

### MariaDB模式（双容器）

```
┌─────────────────┐    ┌─────────────────┐
│   应用容器       │    │   数据库容器     │
│  ┌───────────┐  │    │  ┌───────────┐  │
│  │Go应用程序  │  │◄──►│  │ MariaDB   │  │
│  │5555, 6666 │  │    │  │   3306    │  │
│  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────────────────┘
              Docker网络
           miniblog-network
```

## 部署流程详解

### 阶段1：准备阶段

#### 1.1 环境检查

```bash
# 检查Docker是否安装
docker --version

# 检查Docker Compose是否安装（可选）
docker-compose --version

# 检查系统资源
free -h
df -h
```

#### 1.2 项目准备

```bash
# 克隆项目
git clone https://github.com/onexstack/miniblog.git
cd miniblog

# 检查Go环境
go version

# 检查项目文件
ls -la
```

### 阶段2：构建阶段

#### 2.1 编译Go程序

```bash
# 编译应用程序
make build BINS=mb-apiserver

# 验证编译结果
ls -la _output/platforms/linux/amd64/mb-apiserver
```

#### 2.2 构建Docker镜像

```bash
# 给脚本执行权限
chmod +x docker-deployment/scripts/*.sh

# 构建Docker镜像
./docker-deployment/scripts/build-image.sh
```

**构建过程说明：**

1. 创建临时构建目录
2. 复制编译后的程序
3. 生成优化的Dockerfile
4. 构建Docker镜像
5. 添加版本标签
6. 验证镜像

### 阶段3：部署阶段

#### 3.1 选择部署模式

**内存数据库模式：**

```bash
./docker-deployment/scripts/deploy-memory.sh
```

**MariaDB数据库模式：**

```bash
./docker-deployment/scripts/deploy-mariadb.sh
```

#### 3.2 部署过程详解

**内存数据库模式部署过程：**

1. 清理旧容器
2. 准备配置文件
3. 启动应用容器
4. 等待服务启动
5. 验证部署

**MariaDB模式部署过程：**

1. 清理旧资源
2. 创建Docker网络
3. 启动MariaDB容器
4. 等待数据库初始化
5. 导入数据库结构
6. 准备应用配置
7. 启动应用容器
8. 等待应用启动
9. 验证部署

### 阶段4：验证阶段

#### 4.1 自动测试

```bash
# 运行完整测试
./docker-deployment/scripts/test-deployment.sh

# 指定模式测试
./docker-deployment/scripts/test-deployment.sh memory
./docker-deployment/scripts/test-deployment.sh mariadb
```

#### 4.2 手动验证

```bash
# 健康检查
curl http://localhost:5555/healthz

# 用户注册测试
curl -X POST -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123","nickname":"测试","email":"test@example.com","phone":"13800138000"}' \
  http://localhost:5555/v1/users

# 用户登录测试
curl -X POST -H "Content-Type: application/json" \
  -d '{"username":"root","password":"miniblog1234"}' \
  http://localhost:5555/v1/login
```

### 阶段5：管理阶段

#### 5.1 日常管理

```bash
# 查看服务状态
./docker-deployment/scripts/manage.sh status

# 查看日志
./docker-deployment/scripts/manage.sh logs

# 重启服务
./docker-deployment/scripts/manage.sh restart

# 备份数据（MariaDB模式）
./docker-deployment/scripts/manage.sh backup
```

#### 5.2 监控和维护

```bash
# 查看资源使用
./docker-deployment/scripts/manage.sh stats

# 连接数据库（MariaDB模式）
./docker-deployment/scripts/manage.sh db

# 查看数据库日志（MariaDB模式）
./docker-deployment/scripts/manage.sh db-logs
```

## 配置说明

### 内存数据库配置

```yaml
# docker-deployment/configs/memory-db.yaml
server-mode: grpc-gateway
enable-memory-store: true  # 关键配置
tls:
  use-tls: false
http:
  addr: :5555
grpc:
  addr: :6666
```

### MariaDB数据库配置

```yaml
# docker-deployment/configs/mariadb.yaml
server-mode: grpc-gateway
enable-memory-store: false  # 关键配置
mysql:
  addr: miniblog-mariadb:3306  # 容器名作为主机名
  username: miniblog
  password: miniblog1234
  database: miniblog
```

## 网络和存储

### Docker网络

```bash
# 查看网络
docker network ls
docker network inspect miniblog-network

# 网络配置
Name: miniblog-network
Driver: bridge
Scope: local
```

### 数据持久化

```bash
# 查看数据卷
docker volume ls
docker volume inspect miniblog-db-data

# 数据卷位置
/var/lib/docker/volumes/miniblog-db-data/_data
```

## 端口映射

| 服务 | 容器端口 | 宿主机端口 | 协议 | 用途 |
|------|----------|------------|------|------|
| HTTP API | 5555 | 5555 | HTTP | REST API |
| gRPC API | 6666 | 6666 | gRPC | gRPC服务 |
| MariaDB | 3306 | 3306 | TCP | 数据库连接 |

## 资源需求

### 内存数据库模式

- CPU: 0.1-0.2核
- 内存: 128-256MB
- 磁盘: 50MB

### MariaDB模式

- 应用容器: CPU 0.1核, 内存 128MB
- 数据库容器: CPU 0.1核, 内存 256MB
- 总计: CPU 0.2核, 内存 384MB, 磁盘 200MB

## 安全配置

### 生产环境建议

1. **启用HTTPS**

   ```yaml
   tls:
     use-tls: true
     cert: /path/to/cert.pem
     key: /path/to/key.pem
   ```

2. **修改默认密码**

   ```yaml
   mysql:
     password: your-secure-password
   ```

3. **限制网络访问**

   ```bash
   # 只绑定本地接口
   docker run -p 127.0.0.1:5555:5555 ...
   ```

4. **使用非root用户**

   ```dockerfile
   USER miniblog
   ```

## 故障排查

### 常见问题

1. **容器启动失败**

   ```bash
   docker logs miniblog-app-mariadb
   docker logs miniblog-mariadb
   ```

2. **端口冲突**

   ```bash
   netstat -tlnp | grep 5555
   # 修改端口映射
   docker run -p 8080:5555 ...
   ```

3. **数据库连接失败**

   ```bash
   # 测试网络连接
   docker exec miniblog-app-mariadb ping miniblog-mariadb
   
   # 测试数据库连接
   docker exec miniblog-mariadb mysqladmin ping -u miniblog -pminiblog1234
   ```

4. **数据丢失**

   ```bash
   # 检查数据卷
   docker volume inspect miniblog-db-data
   
   # 恢复备份
   docker exec -i miniblog-mariadb mysql -u root -proot123456 miniblog < backup.sql
   ```

## 升级和维护

### 应用升级

```bash
# 1. 备份数据
./docker-deployment/scripts/manage.sh backup

# 2. 停止应用
./docker-deployment/scripts/manage.sh stop

# 3. 重新编译和构建
make build BINS=mb-apiserver
./docker-deployment/scripts/build-image.sh

# 4. 重新部署
./docker-deployment/scripts/deploy-mariadb.sh
```

### 数据库维护

```bash
# 数据库备份
./docker-deployment/scripts/manage.sh backup

# 数据库优化
docker exec miniblog-mariadb mysql -u root -proot123456 -e "OPTIMIZE TABLE miniblog.user, miniblog.post;"

# 查看数据库状态
docker exec miniblog-mariadb mysql -u root -proot123456 -e "SHOW STATUS;"
```

## 性能优化

### 应用优化

1. **调整连接池**

   ```yaml
   mysql:
     max-idle-connections: 50
     max-open-connections: 100
   ```

2. **调整日志级别**

   ```yaml
   log:
     level: warn  # 生产环境使用warn或error
   ```

### 数据库优化

1. **调整内存配置**

   ```bash
   docker run -e MYSQL_INNODB_BUFFER_POOL_SIZE=256M mariadb
   ```

2. **启用查询缓存**

   ```bash
   docker run -e MYSQL_QUERY_CACHE_SIZE=64M mariadb
   ```

## 监控和日志

### 日志管理

```bash
# 查看实时日志
docker logs -f miniblog-app-mariadb

# 日志轮转
docker run --log-driver=json-file --log-opt max-size=10m --log-opt max-file=3 ...
```

### 监控指标

```bash
# 容器资源使用
docker stats

# 应用健康检查
curl http://localhost:5555/healthz

# 数据库状态
docker exec miniblog-mariadb mysqladmin status -u miniblog -pminiblog1234
```

这个完整的部署指南涵盖了从准备到维护的整个生命周期，确保你能够成功部署和管理MiniBlog系统。
