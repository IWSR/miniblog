# 故障排查指南

本文档提供MiniBlog Docker部署过程中常见问题的解决方案。

## 快速诊断

### 一键诊断脚本

```bash
# 运行诊断
./docker-deployment/scripts/manage.sh status
./docker-deployment/scripts/test-deployment.sh
```

### 基础检查清单

- [ ] Docker服务是否运行
- [ ] 容器是否启动
- [ ] 端口是否被占用
- [ ] 网络连接是否正常
- [ ] 配置文件是否正确
- [ ] 日志中是否有错误

## 常见问题分类

### 1. 环境问题

#### 1.1 Docker未安装或未启动

**症状**:

```bash
$ docker ps
bash: docker: command not found
```

**解决方案**:

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io

# CentOS/RHEL
sudo yum install docker

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 添加用户到docker组
sudo usermod -aG docker $USER
newgrp docker
```

#### 1.2 权限问题

**症状**:

```bash
$ docker ps
permission denied while trying to connect to the Docker daemon socket
```

**解决方案**:

```bash
# 方法1: 使用sudo
sudo docker ps

# 方法2: 添加用户到docker组
sudo usermod -aG docker $USER
# 重新登录或执行
newgrp docker
```

#### 1.3 磁盘空间不足

**症状**:

```bash
no space left on device
```

**解决方案**:

```bash
# 检查磁盘空间
df -h

# 清理Docker资源
docker system prune -a
docker volume prune

# 清理未使用的镜像
docker image prune -a
```

### 2. 构建问题

#### 2.1 Go编译失败

**症状**:

```bash
make: go: command not found
```

**解决方案**:

```bash
# 安装Go
wget https://go.dev/dl/go1.23.4.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz

# 设置环境变量
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# 验证安装
go version
```

#### 2.2 Docker镜像构建失败

**症状**:

```bash
ERROR: failed to solve: failed to read dockerfile
```

**解决方案**:

```bash
# 检查Dockerfile是否存在
ls -la docker-deployment/build/Dockerfile

# 检查构建上下文
ls -la docker-deployment/build/

# 重新构建
./docker-deployment/scripts/build-image.sh
```

#### 2.3 编译后的程序不存在

**症状**:

```bash
找不到编译后的程序，请先运行 make build BINS=mb-apiserver
```

**解决方案**:

```bash
# 检查编译结果
ls -la _output/platforms/linux/amd64/

# 重新编译
make clean
make build BINS=mb-apiserver

# 检查Makefile
cat Makefile | grep build
```

### 3. 容器启动问题

#### 3.1 端口冲突

**症状**:

```bash
bind: address already in use
```

**解决方案**:

```bash
# 检查端口占用
netstat -tlnp | grep 5555
lsof -i :5555

# 停止占用端口的进程
sudo kill -9 PID

# 或者使用不同端口
docker run -p 8080:5555 miniblog:latest
```

#### 3.2 容器立即退出

**症状**:

```bash
$ docker ps
# 容器不在运行列表中

$ docker ps -a
STATUS: Exited (1) 2 seconds ago
```

**解决方案**:

```bash
# 查看容器日志
docker logs container-name

# 查看退出代码
docker ps -a

# 交互式运行调试
docker run -it --rm miniblog:latest /bin/sh

# 检查启动命令
docker inspect container-name | grep -A 10 "Cmd"
```

#### 3.3 配置文件挂载失败

**症状**:

```bash
no such file or directory: config file not found
```

**解决方案**:

```bash
# 检查配置文件是否存在
ls -la /tmp/miniblog-config/mb-apiserver.yaml

# 检查挂载路径
docker inspect container-name | grep -A 10 "Mounts"

# 重新创建配置文件
mkdir -p /tmp/miniblog-config
cp docker-deployment/configs/memory-db.yaml /tmp/miniblog-config/mb-apiserver.yaml
```

### 4. 网络问题

#### 4.1 容器间无法通信

**症状**:

```bash
# 应用容器无法连接数据库
connection refused: miniblog-mariadb:3306
```

**解决方案**:

```bash
# 检查网络是否存在
docker network ls | grep miniblog

# 检查容器是否在同一网络
docker network inspect miniblog-network

# 测试网络连接
docker exec miniblog-app-mariadb ping miniblog-mariadb

# 重新创建网络
docker network rm miniblog-network
docker network create miniblog-network

# 重新启动容器并加入网络
docker run --network miniblog-network ...
```

#### 4.2 外部无法访问服务

**症状**:

```bash
$ curl http://localhost:5555/healthz
curl: (7) Failed to connect to localhost port 5555: Connection refused
```

**解决方案**:

```bash
# 检查容器是否运行
docker ps | grep miniblog

# 检查端口映射
docker port container-name

# 检查防火墙
sudo ufw status
sudo iptables -L

# 检查服务是否在容器内监听
docker exec container-name netstat -tlnp

# 测试容器内服务
docker exec container-name curl http://localhost:5555/healthz
```

### 5. 数据库问题

#### 5.1 MariaDB容器启动失败

**症状**:

```bash
ERROR 2002 (HY000): Can't connect to MySQL server
```

**解决方案**:

```bash
# 查看数据库日志
docker logs miniblog-mariadb

# 检查数据卷
docker volume inspect miniblog-db-data

# 重新初始化数据库
docker stop miniblog-mariadb
docker rm miniblog-mariadb
docker volume rm miniblog-db-data

# 重新部署
./docker-deployment/scripts/deploy-mariadb.sh
```

#### 5.2 数据库初始化失败

**症状**:

```bash
ERROR 1045 (28000): Access denied for user 'miniblog'@'localhost'
```

**解决方案**:

```bash
# 检查环境变量
docker inspect miniblog-mariadb | grep -A 10 "Env"

# 重置数据库密码
docker exec -it miniblog-mariadb mysql -u root -proot123456
mysql> ALTER USER 'miniblog'@'%' IDENTIFIED BY 'miniblog1234';
mysql> FLUSH PRIVILEGES;

# 检查SQL文件
cat configs/miniblog.sql | head -20

# 手动导入SQL
docker cp configs/miniblog.sql miniblog-mariadb:/tmp/
docker exec miniblog-mariadb mysql -u root -proot123456 -e "source /tmp/miniblog.sql"
```

#### 5.3 数据库连接超时

**症状**:

```bash
dial tcp: i/o timeout
```

**解决方案**:

```bash
# 检查数据库是否就绪
docker exec miniblog-mariadb mysqladmin ping -u miniblog -pminiblog1234

# 增加连接超时时间
# 修改应用配置文件中的数据库连接参数

# 检查网络延迟
docker exec miniblog-app-mariadb ping -c 3 miniblog-mariadb
```

### 6. 应用问题

#### 6.1 健康检查失败

**症状**:

```bash
$ curl http://localhost:5555/healthz
curl: (52) Empty reply from server
```

**解决方案**:

```bash
# 检查应用日志
docker logs miniblog-app-mariadb

# 检查应用是否启动完成
docker exec miniblog-app-mariadb ps aux

# 检查配置文件
docker exec miniblog-app-mariadb cat /opt/miniblog/configs/mb-apiserver.yaml

# 手动测试健康检查
docker exec miniblog-app-mariadb wget -O- http://localhost:5555/healthz
```

#### 6.2 JWT认证失败

**症状**:

```bash
{"error":"invalid token"}
```

**解决方案**:

```bash
# 检查JWT密钥配置
grep jwt-key docker-deployment/configs/mariadb.yaml

# 重新登录获取token
curl -X POST -H "Content-Type: application/json" \
  -d '{"username":"root","password":"miniblog1234"}' \
  http://localhost:5555/v1/login

# 检查token格式
echo "YOUR_TOKEN" | base64 -d
```

#### 6.3 API接口返回500错误

**症状**:

```bash
HTTP/1.1 500 Internal Server Error
```

**解决方案**:

```bash
# 查看详细错误日志
docker logs miniblog-app-mariadb | grep ERROR

# 检查数据库连接
docker exec miniblog-app-mariadb nc -zv miniblog-mariadb 3306

# 检查应用配置
docker exec miniblog-app-mariadb cat /opt/miniblog/configs/mb-apiserver.yaml

# 重启应用容器
docker restart miniblog-app-mariadb
```

### 7. 性能问题

#### 7.1 容器资源不足

**症状**:

```bash
# 响应缓慢或超时
```

**解决方案**:

```bash
# 查看资源使用
docker stats

# 增加资源限制
docker run -m 512m --cpus="1.0" miniblog:latest

# 检查系统资源
free -h
top
```

#### 7.2 数据库性能问题

**症状**:

```bash
# 查询缓慢
```

**解决方案**:

```bash
# 查看数据库状态
docker exec miniblog-mariadb mysql -u root -proot123456 -e "SHOW STATUS LIKE 'Threads%';"

# 优化数据库配置
docker run -e MYSQL_INNODB_BUFFER_POOL_SIZE=256M mariadb

# 分析慢查询
docker exec miniblog-mariadb mysql -u root -proot123456 -e "SHOW VARIABLES LIKE 'slow_query_log';"
```

## 调试工具和技巧

### 1. 日志分析

```bash
# 实时查看日志
docker logs -f container-name

# 过滤错误日志
docker logs container-name 2>&1 | grep -i error

# 查看最近的日志
docker logs --tail 50 container-name

# 按时间过滤日志
docker logs --since 2023-01-01T00:00:00 container-name
```

### 2. 容器调试

```bash
# 进入容器
docker exec -it container-name /bin/sh

# 查看容器进程
docker exec container-name ps aux

# 查看容器网络
docker exec container-name netstat -tlnp

# 查看容器文件系统
docker exec container-name ls -la /opt/miniblog/

# 测试容器内网络连接
docker exec container-name ping google.com
docker exec container-name nc -zv miniblog-mariadb 3306
```

### 3. 网络调试

```bash
# 查看网络配置
docker network inspect miniblog-network

# 测试容器间连接
docker exec container1 ping container2

# 查看端口映射
docker port container-name

# 测试端口连通性
telnet localhost 5555
nc -zv localhost 5555
```

### 4. 数据调试

```bash
# 查看数据卷
docker volume inspect miniblog-db-data

# 备份数据
docker run --rm -v miniblog-db-data:/data -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz -C /data .

# 恢复数据
docker run --rm -v miniblog-db-data:/data -v $(pwd):/backup alpine tar xzf /backup/backup.tar.gz -C /data
```

## 预防措施

### 1. 监控和告警

```bash
# 设置资源监控
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# 健康检查监控
while true; do
  curl -f http://localhost:5555/healthz || echo "Health check failed at $(date)"
  sleep 30
done
```

### 2. 定期维护

```bash
# 定期清理
docker system prune -f

# 定期备份
./docker-deployment/scripts/manage.sh backup

# 定期更新
docker pull mariadb:10.11
```

### 3. 配置管理

```bash
# 版本控制配置文件
git add docker-deployment/configs/
git commit -m "Update configuration"

# 配置文件验证
yamllint docker-deployment/configs/mariadb.yaml
```

## 紧急恢复

### 1. 快速重启

```bash
# 停止所有服务
./docker-deployment/scripts/manage.sh stop

# 清理问题容器
docker rm -f $(docker ps -aq --filter "name=miniblog")

# 重新部署
./docker-deployment/scripts/deploy-mariadb.sh
```

### 2. 数据恢复

```bash
# 从备份恢复数据库
docker exec -i miniblog-mariadb mysql -u root -proot123456 miniblog < backup.sql

# 验证数据
docker exec miniblog-mariadb mysql -u miniblog -pminiblog1234 miniblog -e "SELECT COUNT(*) FROM user;"
```

### 3. 回滚到上一个版本

```bash
# 使用之前的镜像
docker run -d --name miniblog-app miniblog:previous-version

# 或者重新构建
git checkout previous-commit
./docker-deployment/scripts/build-image.sh
./docker-deployment/scripts/deploy-mariadb.sh
```

## 获取帮助

### 1. 收集诊断信息

```bash
# 系统信息
uname -a
docker version
docker info

# 容器信息
docker ps -a
docker logs container-name
docker inspect container-name

# 网络信息
docker network ls
ip addr show

# 资源信息
free -h
df -h
```

### 2. 创建问题报告

```bash
# 生成诊断报告
echo "=== System Info ===" > debug-report.txt
uname -a >> debug-report.txt
docker version >> debug-report.txt

echo "=== Container Status ===" >> debug-report.txt
docker ps -a >> debug-report.txt

echo "=== Container Logs ===" >> debug-report.txt
docker logs miniblog-app-mariadb >> debug-report.txt 2>&1

echo "=== Network Info ===" >> debug-report.txt
docker network ls >> debug-report.txt
```

这个故障排查指南涵盖了MiniBlog Docker部署中可能遇到的大部分问题，按照这些步骤通常可以解决常见问题。
