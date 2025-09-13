# 服务器配置和GitHub Actions对接指南

## GitHub Secrets配置步骤

### 第1步：访问GitHub仓库设置

1. 打开你的GitHub仓库页面
2. 点击 `Settings` 标签页（在仓库顶部导航栏）
3. 在左侧菜单中找到 `Secrets and variables`
4. 点击 `Actions`

### 第2步：添加Secrets

点击 `New repository secret` 按钮，逐个添加以下Secrets：

#### 必需的镜像推送Secrets

```
Name: GHCR_TOKEN
Value: ghp_xxxxxxxxxxxxxxxxxxxx
```

#### 服务器连接Secrets（用于自动部署）

```
Name: PROD_SERVER_HOST
Value: 192.168.1.100  (你的服务器IP地址)

Name: PROD_SERVER_USER  
Value: deploy  (服务器用户名)

Name: PROD_SERVER_SSH_KEY
Value: -----BEGIN OPENSSH PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
(完整的SSH私钥内容)
-----END OPENSSH PRIVATE KEY-----

Name: PROD_SERVER_PORT
Value: 22  (SSH端口，默认22)
```

#### 测试环境Secrets（可选）

```
Name: STAGING_SERVER_HOST
Value: 192.168.1.101

Name: STAGING_SERVER_USER
Value: deploy

Name: STAGING_SERVER_SSH_KEY  
Value: -----BEGIN OPENSSH PRIVATE KEY-----
(测试服务器的SSH私钥)
-----END OPENSSH PRIVATE KEY-----

Name: STAGING_SERVER_PORT
Value: 22
```

## 服务器端准备工作

### 第1步：创建部署用户

```bash
# 在服务器上创建专门的部署用户
sudo adduser deploy
sudo usermod -aG docker deploy  # 添加到docker组
sudo usermod -aG sudo deploy    # 添加sudo权限（可选）
```

### 第2步：配置SSH密钥认证

```bash
# 在你的本地机器上生成SSH密钥对
ssh-keygen -t rsa -b 4096 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy

# 将公钥复制到服务器
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub deploy@your-server-ip

# 或者手动复制
cat ~/.ssh/github_actions_deploy.pub
# 然后在服务器上：
sudo -u deploy mkdir -p /home/deploy/.ssh
sudo -u deploy nano /home/deploy/.ssh/authorized_keys
# 粘贴公钥内容，保存退出

# 设置正确的权限
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
```

### 第3步：测试SSH连接

```bash
# 在本地测试SSH连接
ssh -i ~/.ssh/github_actions_deploy deploy@your-server-ip

# 测试Docker权限
docker ps
docker pull hello-world
```

### 第4步：安装必要软件

```bash
# 确保服务器安装了Docker
sudo apt update
sudo apt install docker.io docker-compose

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 确保deploy用户可以使用Docker
sudo usermod -aG docker deploy
# 重新登录或执行
newgrp docker
```

### 第5步：创建部署目录

```bash
# 创建应用部署目录
sudo mkdir -p /opt/miniblog
sudo chown deploy:deploy /opt/miniblog

# 创建配置目录
mkdir -p /opt/miniblog/configs
mkdir -p /opt/miniblog/logs
```

## GitHub Personal Access Token创建

### 第1步：访问GitHub设置

1. 点击GitHub右上角头像
2. 选择 `Settings`
3. 在左侧菜单中选择 `Developer settings`
4. 选择 `Personal access tokens`
5. 选择 `Tokens (classic)`

### 第2步：创建Token

1. 点击 `Generate new token (classic)`
2. 填写Token描述：`MiniBlog GitHub Actions`
3. 选择过期时间：建议选择 `90 days` 或 `No expiration`
4. 选择权限：
   - ✅ `write:packages` - 推送镜像到GitHub Container Registry
   - ✅ `read:packages` - 拉取镜像
   - ✅ `repo` - 访问仓库（如果是私有仓库）

5. 点击 `Generate token`
6. **重要：立即复制Token值，页面刷新后将无法再次查看**

## 服务器安全配置

### SSH安全加固

```bash
# 编辑SSH配置
sudo nano /etc/ssh/sshd_config

# 建议的安全配置
Port 22                          # 可以改为其他端口
PermitRootLogin no              # 禁止root登录
PasswordAuthentication no       # 禁用密码登录
PubkeyAuthentication yes        # 启用密钥登录
AuthorizedKeysFile .ssh/authorized_keys

# 重启SSH服务
sudo systemctl restart sshd
```

### 防火墙配置

```bash
# 配置UFW防火墙
sudo ufw allow ssh
sudo ufw allow 5555/tcp  # MiniBlog HTTP端口
sudo ufw allow 6666/tcp  # MiniBlog gRPC端口
sudo ufw allow 3306/tcp  # MySQL端口（如果需要外部访问）
sudo ufw enable
```

### Docker安全配置

```bash
# 限制Docker daemon访问
sudo nano /etc/docker/daemon.json

{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}

# 重启Docker
sudo systemctl restart docker
```

## 部署脚本准备

在服务器上创建部署脚本：

```bash
# 创建部署脚本
nano /opt/miniblog/deploy.sh
```

```bash
#!/bin/bash
# 服务器端部署脚本

set -e

IMAGE_TAG=${1:-latest}
DEPLOY_MODE=${2:-mariadb}

echo "🚀 开始部署 MiniBlog"
echo "镜像标签: $IMAGE_TAG"
echo "部署模式: $DEPLOY_MODE"

cd /opt/miniblog

# 拉取最新镜像
echo "📦 拉取Docker镜像..."
docker pull ghcr.io/your-username/miniblog:$IMAGE_TAG

if [ "$DEPLOY_MODE" = "mariadb" ]; then
    echo "🗄️  部署MariaDB模式..."
    
    # 创建网络
    docker network create miniblog-network 2>/dev/null || true
    
    # 启动MariaDB（如果不存在）
    if ! docker ps | grep -q miniblog-mariadb; then
        echo "启动MariaDB容器..."
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
        
        sleep 30  # 等待数据库启动
    fi
    
    # 停止旧的应用容器
    docker stop miniblog-app 2>/dev/null || true
    docker rm miniblog-app 2>/dev/null || true
    
    # 创建配置文件
    cat > configs/mb-apiserver.yaml << 'EOF'
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
  output-paths: [stdout, /opt/miniblog/logs/app.log]
EOF
    
    # 启动应用容器
    docker run -d \
      --name miniblog-app \
      --network miniblog-network \
      -p 5555:5555 \
      -p 6666:6666 \
      -v /opt/miniblog/configs/mb-apiserver.yaml:/opt/miniblog/configs/mb-apiserver.yaml \
      -v /opt/miniblog/logs:/opt/miniblog/logs \
      --restart unless-stopped \
      ghcr.io/your-username/miniblog:$IMAGE_TAG \
      --config=/opt/miniblog/configs/mb-apiserver.yaml

else
    echo "💾 部署内存数据库模式..."
    
    # 停止旧容器
    docker stop miniblog-app 2>/dev/null || true
    docker rm miniblog-app 2>/dev/null || true
    
    # 创建配置文件
    cat > configs/mb-apiserver.yaml << 'EOF'
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
  output-paths: [stdout, /opt/miniblog/logs/app.log]
EOF
    
    # 启动容器
    docker run -d \
      --name miniblog-app \
      -p 5555:5555 \
      -p 6666:6666 \
      -v /opt/miniblog/configs/mb-apiserver.yaml:/opt/miniblog/configs/mb-apiserver.yaml \
      -v /opt/miniblog/logs:/opt/miniblog/logs \
      --restart unless-stopped \
      ghcr.io/your-username/miniblog:$IMAGE_TAG \
      --config=/opt/miniblog/configs/mb-apiserver.yaml
fi

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 健康检查
echo "🔍 执行健康检查..."
for i in {1..30}; do
    if curl -f http://localhost:5555/healthz; then
        echo "✅ 服务启动成功！"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ 服务启动失败"
        exit 1
    fi
    sleep 2
done

echo "🎉 部署完成！"
```

```bash
# 给脚本执行权限
chmod +x /opt/miniblog/deploy.sh
```

## 测试连接

### 本地测试SSH连接

```bash
# 使用生成的私钥测试连接
ssh -i ~/.ssh/github_actions_deploy deploy@your-server-ip

# 测试部署脚本
./deploy.sh latest mariadb
```

### 测试GitHub Actions连接

创建一个简单的测试工作流：

```yaml
# .github/workflows/test-connection.yml
name: Test Server Connection

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - name: Test SSH Connection
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.PROD_SERVER_HOST }}
        username: ${{ secrets.PROD_SERVER_USER }}
        key: ${{ secrets.PROD_SERVER_SSH_KEY }}
        port: ${{ secrets.PROD_SERVER_PORT }}
        script: |
          echo "✅ SSH连接成功！"
          echo "当前用户: $(whoami)"
          echo "Docker版本: $(docker --version)"
          echo "系统信息: $(uname -a)"
```

## 故障排查

### SSH连接问题

```bash
# 检查SSH服务状态
sudo systemctl status sshd

# 查看SSH日志
sudo tail -f /var/log/auth.log

# 测试SSH连接（详细模式）
ssh -v -i ~/.ssh/github_actions_deploy deploy@your-server-ip
```

### Docker权限问题

```bash
# 检查用户是否在docker组中
groups deploy

# 重新添加到docker组
sudo usermod -aG docker deploy

# 重启Docker服务
sudo systemctl restart docker
```

### 防火墙问题

```bash
# 检查防火墙状态
sudo ufw status

# 检查端口是否开放
sudo netstat -tlnp | grep :5555
```

这个指南涵盖了服务器配置的所有方面，按照这些步骤配置后，GitHub Actions就可以自动部署到你的服务器了。
