# MiniBlog Docker 快速开始

## 🚀 一分钟快速部署

### 前提条件

- 已安装Docker
- 2C4G服务器（推荐）
- 项目已克隆到本地

### 快速部署命令

```bash
# 1. 进入项目目录
cd miniblog

# 2. 给脚本执行权限
chmod +x docker-deployment/scripts/*.sh

# 3. 一键部署（MariaDB模式）
./docker-deployment/scripts/deploy-mariadb.sh

# 4. 测试部署
./docker-deployment/scripts/test-deployment.sh
```

### 验证部署

```bash
# 健康检查
curl http://localhost:5555/healthz

# 用户登录
curl -X POST -H "Content-Type: application/json" \
  -d '{"username":"root","password":"miniblog1234"}' \
  http://localhost:5555/v1/login
```

## 📋 完整部署流程

### 第1步：环境准备

```bash
# 检查Docker
docker --version

# 检查系统资源
free -h
df -h
```

### 第2步：项目构建

```bash
# 编译Go程序
make build BINS=mb-apiserver

# 构建Docker镜像
./docker-deployment/scripts/build-image.sh
```

### 第3步：选择部署模式

#### 内存数据库模式（开发/测试）

```bash
./docker-deployment/scripts/deploy-memory.sh
```

#### MariaDB数据库模式（生产环境）

```bash
./docker-deployment/scripts/deploy-mariadb.sh
```

### 第4步：验证和测试

```bash
# 运行测试
./docker-deployment/scripts/test-deployment.sh

# 查看状态
./docker-deployment/scripts/manage.sh status
```

## 🔧 日常管理

### 服务管理

```bash
# 查看状态
./docker-deployment/scripts/manage.sh status

# 查看日志
./docker-deployment/scripts/manage.sh logs

# 重启服务
./docker-deployment/scripts/manage.sh restart

# 停止服务
./docker-deployment/scripts/manage.sh stop

# 启动服务
./docker-deployment/scripts/manage.sh start
```

### 数据库管理（MariaDB模式）

```bash
# 连接数据库
./docker-deployment/scripts/manage.sh db

# 备份数据库
./docker-deployment/scripts/manage.sh backup

# 查看数据库日志
./docker-deployment/scripts/manage.sh db-logs
```

### 监控和维护

```bash
# 查看资源使用
./docker-deployment/scripts/manage.sh stats

# 运行健康检查
./docker-deployment/scripts/test-deployment.sh
```

## 🌐 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| HTTP API | <http://localhost:5555> | REST API接口 |
| gRPC API | localhost:6666 | gRPC服务 |
| 健康检查 | <http://localhost:5555/healthz> | 服务健康状态 |
| 数据库 | localhost:3306 | MariaDB数据库 |

## 📊 默认账户

| 项目 | 用户名 | 密码 |
|------|--------|------|
| 应用管理员 | root | miniblog1234 |
| 数据库root | root | root123456 |
| 数据库用户 | miniblog | miniblog1234 |

## 🛠️ 故障排查

### 常见问题

```bash
# 容器无法启动
docker logs container-name

# 端口被占用
netstat -tlnp | grep 5555

# 数据库连接失败
docker exec miniblog-mariadb mysqladmin ping -u miniblog -pminiblog1234
```

### 重新部署

```bash
# 清理所有资源
./docker-deployment/scripts/manage.sh clean

# 重新部署
./docker-deployment/scripts/deploy-mariadb.sh
```

## 📚 更多文档

- [完整部署指南](docs/deployment-guide.md)
- [Docker基础知识](docs/docker-basics.md)
- [故障排查指南](docs/troubleshooting.md)

## 🎯 部署模式对比

| 特性 | 内存数据库 | MariaDB数据库 |
|------|------------|---------------|
| 容器数量 | 1个 | 2个 |
| 数据持久化 | ❌ | ✅ |
| 资源占用 | 低 | 中等 |
| 部署复杂度 | 简单 | 中等 |
| 适用场景 | 开发/测试 | 生产环境 |

## ⚡ 性能优化

### 资源配置

```bash
# 限制容器资源
docker run --cpus="0.5" -m 256m miniblog:latest
```

### 数据库优化

```bash
# 调整数据库配置
docker run -e MYSQL_INNODB_BUFFER_POOL_SIZE=256M mariadb
```

## 🔒 安全建议

1. **修改默认密码**
2. **启用HTTPS**（修改配置文件）
3. **限制网络访问**
4. **定期备份数据**
5. **监控日志异常**

---

**需要帮助？** 查看 [故障排查指南](docs/troubleshooting.md) 或运行诊断命令：

```bash
./docker-deployment/scripts/manage.sh status
./docker-deployment/scripts/test-deployment.sh
```
