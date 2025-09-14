# GitHub Secrets 配置详细指南

## 概述

GitHub Secrets是存储敏感信息（如密码、API密钥、SSH私钥等）的安全方式。本指南将详细说明如何配置MiniBlog项目所需的所有Secrets。

## 访问GitHub Secrets设置

### 第1步：打开仓库设置

1. 访问你的GitHub仓库页面
2. 点击仓库顶部的 `Settings` 标签页
3. 在左侧菜单中找到 `Secrets and variables`
4. 点击 `Actions`

### 第2步：添加Secrets

点击 `New repository secret` 按钮来添加新的Secret。

## 必需的Secrets配置

### 1. 容器注册表认证

#### GitHub Container Registry (推荐)

```
Name: GHCR_TOKEN
Value: ghp_xxxxxxxxxxxxxxxxxxxx
```

**获取方法:**

1. 访问 GitHub Settings → Developer settings → Personal access tokens
2. 点击 "Generate new token (classic)"
3. 选择权限：`write:packages`, `read:packages`
4. 复制生成的token

#### Docker Hub (可选)

```
Name: DOCKERHUB_USERNAME
Value: your_dockerhub_username

Name: DOCKERHUB_TOKEN
Value: dckr_pat_xxxxxxxxxxxx
```

### 2. 生产服务器配置

```
Name: PROD_SERVER_HOST
Value: 192.168.1.100
说明: 生产服务器的IP地址或域名

Name: PROD_SERVER_USER
Value: deploy
说明: 服务器上的部署用户名

Name: PROD_SERVER_SSH_KEY
Value: -----BEGIN OPENSSH PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
(完整的SSH私钥内容)
-----END OPENSSH PRIVATE KEY-----
说明: SSH私钥，用于连接服务器

Name: PROD_SERVER_PORT
Value: 22
说明: SSH端口号，默认22
```

### 3. 测试服务器配置 (可选)

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

## SSH密钥配置详解

### 生成SSH密钥对

在你的本地机器上执行：

```bash
# 生成SSH密钥对
ssh-keygen -t rsa -b 4096 -C "github-actions-miniblog" -f ~/.ssh/miniblog_deploy

# 查看私钥内容（用于GitHub Secret）
cat ~/.ssh/miniblog_deploy

# 查看公钥内容（用于服务器配置）
cat ~/.ssh/miniblog_deploy.pub
```

### 配置服务器SSH访问

```bash
# 将公钥复制到服务器
ssh-copy-id -i ~/.ssh/miniblog_deploy.pub deploy@your-server-ip

# 或者手动配置
ssh deploy@your-server-ip
mkdir -p ~/.ssh
nano ~/.ssh/authorized_keys
# 粘贴公钥内容，保存退出

# 设置正确权限
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### 测试SSH连接

```bash
# 测试SSH连接
ssh -i ~/.ssh/miniblog_deploy deploy@your-server-ip

# 测试Docker权限
docker ps
```

## 环境配置 (可选但推荐)

### 创建GitHub环境

1. 在仓库设置中，点击左侧的 `Environments`
2. 点击 `New environment`
3. 创建环境：`production` 和 `staging`

### 环境级别的Secrets

为每个环境配置独立的Secrets：

**Production环境:**

- `SERVER_HOST`: 生产服务器地址
- `SERVER_USER`: 生产服务器用户
- `SERVER_SSH_KEY`: 生产服务器SSH密钥
- `SERVER_PORT`: 生产服务器SSH端口

**Staging环境:**

- `SERVER_HOST`: 测试服务器地址
- `SERVER_USER`: 测试服务器用户
- `SERVER_SSH_KEY`: 测试服务器SSH密钥
- `SERVER_PORT`: 测试服务器SSH端口

## 配置验证

### 创建测试工作流

创建 `.github/workflows/test-secrets.yml`：

```yaml
name: Test Secrets Configuration

on:
  workflow_dispatch:

jobs:
  test-secrets:
    runs-on: ubuntu-latest
    steps:
    - name: Test GHCR Token
      run: |
        if [ -n "${{ secrets.GHCR_TOKEN }}" ]; then
          echo "✅ GHCR_TOKEN 已配置"
        else
          echo "❌ GHCR_TOKEN 未配置"
        fi

    - name: Test Server Connection
      if: ${{ secrets.PROD_SERVER_HOST }}
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.PROD_SERVER_HOST }}
        username: ${{ secrets.PROD_SERVER_USER }}
        key: ${{ secrets.PROD_SERVER_SSH_KEY }}
        port: ${{ secrets.PROD_SERVER_PORT || '22' }}
        script: |
          echo "✅ SSH连接成功"
          echo "服务器信息: $(uname -a)"
          echo "Docker版本: $(docker --version)"
          echo "当前用户: $(whoami)"
          echo "用户组: $(groups)"
```

### 运行测试

1. 访问仓库的 `Actions` 标签页
2. 选择 `Test Secrets Configuration` 工作流
3. 点击 `Run workflow`
4. 查看运行结果，确认所有配置正确

## 安全最佳实践

### 1. 最小权限原则

- 只给予必要的权限
- 定期审查和轮换密钥
- 使用专门的部署用户

### 2. SSH密钥管理

```bash
# 为不同项目使用不同的SSH密钥
ssh-keygen -t rsa -b 4096 -C "project-name" -f ~/.ssh/project_deploy

# 定期轮换SSH密钥
ssh-keygen -t rsa -b 4096 -C "new-key-$(date +%Y%m%d)" -f ~/.ssh/new_deploy_key
```

### 3. 服务器安全

```bash
# 禁用密码登录
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no

# 配置防火墙
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 5555/tcp

# 使用Fail2Ban
sudo apt install fail2ban
```

### 4. 监控和审计

- 定期检查GitHub Actions日志
- 监控服务器访问日志
- 设置异常登录告警

## 常见问题排查

### 1. SSH连接失败

```bash
# 检查SSH密钥格式
ssh-keygen -l -f ~/.ssh/miniblog_deploy

# 测试连接（详细模式）
ssh -v -i ~/.ssh/miniblog_deploy deploy@server-ip

# 检查服务器SSH日志
sudo tail -f /var/log/auth.log
```

### 2. Docker权限问题

```bash
# 检查用户是否在docker组中
groups deploy

# 重新添加到docker组
sudo usermod -aG docker deploy

# 重新登录或执行
newgrp docker
```

### 3. 防火墙问题

```bash
# 检查防火墙状态
sudo ufw status

# 检查端口监听
sudo netstat -tlnp | grep :5555
```

### 4. GitHub Token权限问题

- 确保Token有 `write:packages` 权限
- 检查Token是否过期
- 验证仓库访问权限

## Secret值示例

### SSH私钥格式

```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAlwAAAAdzc2gtcn
NhAAAAAwEAAQAAAIEA1234567890abcdef...
(多行私钥内容)
...xyz890AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
-----END OPENSSH PRIVATE KEY-----
```

### GitHub Token格式

```
ghp_1234567890abcdef1234567890abcdef123456
```

### 服务器信息格式

```
HOST: 192.168.1.100 或 example.com
USER: deploy
PORT: 22
```

## 配置完成检查清单

- [ ] GHCR_TOKEN 已配置并测试
- [ ] 生产服务器SSH连接已配置并测试
- [ ] 测试服务器SSH连接已配置（如果需要）
- [ ] SSH密钥权限正确设置
- [ ] 服务器Docker权限配置正确
- [ ] 防火墙规则配置正确
- [ ] 测试工作流运行成功
- [ ] 所有Secrets值格式正确
- [ ] 环境配置（如果使用）

完成这些配置后，GitHub Actions就可以自动构建镜像并部署到你的服务器了！
