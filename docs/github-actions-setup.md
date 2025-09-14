# GitHub Actions 配置指南

## 必需的GitHub Secrets

在你的GitHub仓库中，进入 `Settings` → `Secrets and variables` → `Actions`，添加以下Secrets：

### Docker Hub相关（如果推送到Docker Hub）

- `DOCKERHUB_USERNAME`: Docker Hub用户名
- `DOCKERHUB_TOKEN`: Docker Hub访问令牌

### GitHub Container Registry相关（推荐）

- `GHCR_TOKEN`: GitHub Personal Access Token (需要packages权限)

### 服务器部署相关（可选）

- `SERVER_HOST`: 服务器IP地址
- `SERVER_USER`: 服务器用户名
- `SERVER_SSH_KEY`: SSH私钥
- `SERVER_PORT`: SSH端口（默认22）

## GitHub Personal Access Token创建步骤

1. 访问 GitHub Settings → Developer settings → Personal access tokens
2. 点击 "Generate new token (classic)"
3. 选择权限：
   - `write:packages` - 推送到GitHub Container Registry
   - `read:packages` - 拉取镜像
4. 复制生成的token到 `GHCR_TOKEN`

## Docker Hub Token创建步骤

1. 登录 Docker Hub
2. 访问 Account Settings → Security
3. 点击 "New Access Token"
4. 选择权限：Read, Write, Delete
5. 复制token到 `DOCKERHUB_TOKEN`
