#!/bin/bash

# MiniBlog 服务器配置脚本
# 用于快速配置服务器以支持GitHub Actions自动部署

set -e

# 颜色输出
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

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    error_exit "请使用root用户运行此脚本: sudo $0"
fi

echo "=========================================="
echo "  MiniBlog 服务器配置脚本"
echo "=========================================="

# 获取用户输入
read -p "请输入部署用户名 (默认: deploy): " DEPLOY_USER
DEPLOY_USER=${DEPLOY_USER:-deploy}

read -p "请输入SSH端口 (默认: 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

echo ""
info_msg "配置信息:"
echo "  部署用户: $DEPLOY_USER"
echo "  SSH端口: $SSH_PORT"
echo ""

read -p "确认开始配置? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "配置已取消"
    exit 0
fi

echo ""
echo "第1步：系统更新"
info_msg "更新系统包..."
apt update && apt upgrade -y
success_msg "系统更新完成"

echo ""
echo "第2步：安装必要软件"
info_msg "安装Docker和其他工具..."
apt install -y \
    docker.io \
    docker-compose \
    curl \
    wget \
    git \
    ufw \
    fail2ban \
    htop \
    nano

# 启动Docker服务
systemctl start docker
systemctl enable docker
success_msg "Docker安装完成"

echo ""
echo "第3步：创建部署用户"
if id "$DEPLOY_USER" &>/dev/null; then
    warning_msg "用户 $DEPLOY_USER 已存在"
else
    info_msg "创建用户 $DEPLOY_USER..."
    adduser --disabled-password --gecos "" $DEPLOY_USER
    success_msg "用户创建完成"
fi

# 添加用户到docker组
usermod -aG docker $DEPLOY_USER
success_msg "用户已添加到docker组"

echo ""
echo "第4步：配置SSH"
info_msg "配置SSH服务..."

# 备份SSH配置
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# 配置SSH
cat > /etc/ssh/sshd_config << EOF
# MiniBlog SSH配置
Port $SSH_PORT
Protocol 2

# 认证配置
PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# 安全配置
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# 连接配置
ClientAliveInterval 60
ClientAliveCountMax 3
MaxAuthTries 3
MaxSessions 10
EOF

# 重启SSH服务
systemctl restart sshd
success_msg "SSH配置完成"

echo ""
echo "第5步：配置防火墙"
info_msg "配置UFW防火墙..."

# 重置防火墙规则
ufw --force reset

# 配置防火墙规则
ufw default deny incoming
ufw default allow outgoing

# 允许SSH
ufw allow $SSH_PORT/tcp comment 'SSH'

# 允许MiniBlog端口
ufw allow 5555/tcp comment 'MiniBlog HTTP (Production)'
ufw allow 5556/tcp comment 'MiniBlog HTTP (Staging)'
ufw allow 6666/tcp comment 'MiniBlog gRPC (Production)'
ufw allow 6667/tcp comment 'MiniBlog gRPC (Staging)'

# 允许MySQL端口（可选）
ufw allow 3306/tcp comment 'MySQL (Production)'
ufw allow 3307/tcp comment 'MySQL (Staging)'

# 启用防火墙
ufw --force enable
success_msg "防火墙配置完成"

echo ""
echo "第6步：配置Fail2Ban"
info_msg "配置Fail2Ban..."

# 创建SSH jail配置
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

# 启动Fail2Ban
systemctl enable fail2ban
systemctl start fail2ban
success_msg "Fail2Ban配置完成"

echo ""
echo "第7步：创建部署目录"
info_msg "创建应用目录..."

# 创建目录结构
mkdir -p /opt/miniblog-prod
mkdir -p /opt/miniblog-staging
mkdir -p /opt/miniblog-prod/configs
mkdir -p /opt/miniblog-prod/logs
mkdir -p /opt/miniblog-staging/configs
mkdir -p /opt/miniblog-staging/logs

# 设置目录权限
chown -R $DEPLOY_USER:$DEPLOY_USER /opt/miniblog-*
success_msg "目录创建完成"

echo ""
echo "第8步：生成SSH密钥对"
info_msg "为GitHub Actions生成SSH密钥对..."

# 切换到部署用户
sudo -u $DEPLOY_USER bash << 'EOSU'
cd /home/$USER

# 创建.ssh目录
mkdir -p .ssh
chmod 700 .ssh

# 生成SSH密钥对
ssh-keygen -t rsa -b 4096 -C "github-actions-deploy" -f .ssh/github_actions_deploy -N ""

# 将公钥添加到authorized_keys
cat .ssh/github_actions_deploy.pub >> .ssh/authorized_keys
chmod 600 .ssh/authorized_keys

echo "SSH密钥对已生成"
EOSU

success_msg "SSH密钥对生成完成"

echo ""
echo "第9步：配置Docker"
info_msg "优化Docker配置..."

# 创建Docker daemon配置
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
EOF

# 重启Docker
systemctl restart docker
success_msg "Docker配置完成"

echo ""
echo "第10步：创建管理脚本"
info_msg "创建服务管理脚本..."

# 创建服务管理脚本
cat > /opt/manage-miniblog.sh << 'EOF'
#!/bin/bash

# MiniBlog 服务管理脚本

show_help() {
    echo "MiniBlog 服务管理脚本"
    echo ""
    echo "用法: $0 [命令] [环境]"
    echo ""
    echo "命令:"
    echo "  status    查看服务状态"
    echo "  logs      查看日志"
    echo "  restart   重启服务"
    echo "  stop      停止服务"
    echo "  start     启动服务"
    echo "  clean     清理资源"
    echo ""
    echo "环境:"
    echo "  prod      生产环境"
    echo "  staging   测试环境"
    echo "  all       所有环境 (默认)"
    echo ""
}

get_containers() {
    local env=$1
    if [ "$env" = "prod" ]; then
        echo "miniblog-prod miniblog-mariadb-production"
    elif [ "$env" = "staging" ]; then
        echo "miniblog-staging miniblog-mariadb-staging"
    else
        echo "miniblog-prod miniblog-staging miniblog-mariadb-production miniblog-mariadb-staging"
    fi
}

case "$1" in
    status)
        echo "MiniBlog 服务状态:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep miniblog
        ;;
    logs)
        ENV=${2:-prod}
        if [ "$ENV" = "prod" ]; then
            docker logs -f miniblog-prod
        else
            docker logs -f miniblog-staging
        fi
        ;;
    restart)
        ENV=${2:-all}
        CONTAINERS=$(get_containers $ENV)
        echo "重启容器: $CONTAINERS"
        docker restart $CONTAINERS 2>/dev/null || true
        ;;
    stop)
        ENV=${2:-all}
        CONTAINERS=$(get_containers $ENV)
        echo "停止容器: $CONTAINERS"
        docker stop $CONTAINERS 2>/dev/null || true
        ;;
    start)
        ENV=${2:-all}
        CONTAINERS=$(get_containers $ENV)
        echo "启动容器: $CONTAINERS"
        docker start $CONTAINERS 2>/dev/null || true
        ;;
    clean)
        echo "⚠️  这将删除所有MiniBlog容器和数据！"
        read -p "确认继续? (y/N): " confirm
        if [[ $confirm == [yY] ]]; then
            docker stop $(docker ps -q --filter "name=miniblog") 2>/dev/null || true
            docker rm $(docker ps -aq --filter "name=miniblog") 2>/dev/null || true
            docker volume rm $(docker volume ls -q --filter "name=miniblog") 2>/dev/null || true
            docker network rm $(docker network ls -q --filter "name=miniblog") 2>/dev/null || true
            echo "清理完成"
        fi
        ;;
    *)
        show_help
        ;;
esac
EOF

chmod +x /opt/manage-miniblog.sh
chown $DEPLOY_USER:$DEPLOY_USER /opt/manage-miniblog.sh
success_msg "管理脚本创建完成"

echo ""
echo "=========================================="
success_msg "服务器配置完成！"
echo "=========================================="

echo ""
echo "📋 配置摘要:"
echo "   • 部署用户: $DEPLOY_USER"
echo "   • SSH端口: $SSH_PORT"
echo "   • 防火墙: 已启用"
echo "   • Fail2Ban: 已启用"
echo "   • Docker: 已安装并配置"

echo ""
echo "🔑 SSH密钥信息:"
echo "   • 私钥位置: /home/$DEPLOY_USER/.ssh/github_actions_deploy"
echo "   • 公钥位置: /home/$DEPLOY_USER/.ssh/github_actions_deploy.pub"

echo ""
echo "📝 下一步操作:"
echo "1. 复制私钥内容到GitHub Secrets:"
echo "   sudo cat /home/$DEPLOY_USER/.ssh/github_actions_deploy"
echo ""
echo "2. 在GitHub仓库设置中添加以下Secrets:"
echo "   PROD_SERVER_HOST=$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo "   PROD_SERVER_USER=$DEPLOY_USER"
echo "   PROD_SERVER_SSH_KEY=<私钥内容>"
echo "   PROD_SERVER_PORT=$SSH_PORT"
echo ""
echo "3. 测试SSH连接:"
echo "   ssh -i /path/to/private/key -p $SSH_PORT $DEPLOY_USER@$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo ""
echo "4. 使用管理脚本:"
echo "   /opt/manage-miniblog.sh status"

echo ""
warning_msg "重要提醒:"
echo "• 请妥善保管SSH私钥"
echo "• 建议定期更新系统和Docker"
echo "• 监控服务器资源使用情况"
echo "• 定期备份重要数据"

echo ""
info_msg "服务器已准备就绪，可以接受GitHub Actions部署！"