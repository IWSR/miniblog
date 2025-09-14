# GitHub Actions 使用指南

## 概述

本项目提供了完整的GitHub Actions CI/CD流水线，支持自动化构建、测试、安全扫描和部署。

## 工作流文件说明

### 1. 主要工作流

| 文件 | 触发条件 | 功能 |
|------|----------|------|
| `build-and-deploy.yml` | push到main/develop, 创建tag | 完整的CI/CD流程 |
| `build-only.yml` | push到main/develop, PR | 仅构建和推送镜像 |
| `pr-check.yml` | 创建PR | 代码质量检查 |
| `manual-deploy.yml` | 手动触发 | 手动部署到指定环境 |

### 2. 工作流详细功能

#### `build-and-deploy.yml` (完整流程)

```mermaid
graph TD
    A[代码检查] --> B[构建镜像]
    B --> C[安全扫描]
    C --> D{分支判断}
    D -->|develop| E[部署到测试环境]
    D -->|tag v*| F[部署到生产环境]
    F --> G[创建Release]
```

**功能包括:**

- 代码质量检查和测试
- 构建多架构Docker镜像
- 安全漏洞扫描
- 自动部署到测试/生产环境
- 创建GitHub Release

#### `build-only.yml` (简化版本)

- 适合只需要CI功能的场景
- 构建并推送Docker镜像到GitHub Container Registry
- 支持多架构构建 (linux/amd64, linux/arm64)

#### `pr-check.yml` (PR检查)

- 代码格式检查
- 静态分析 (go vet)
- 单元测试和覆盖率检查
- 编译验证

#### `manual-deploy.yml` (手动部署)

- 支持选择部署环境 (staging/production)
- 支持选择镜像标签
- 支持选择部署模式 (memory/mariadb)

## 配置步骤

### 第1步：Fork仓库并克隆

```bash
# Fork GitHub仓库后克隆到本地
git clone https://github.com/YOUR_USERNAME/miniblog.git
cd miniblog
```

### 第2步：配置GitHub Secrets

在GitHub仓库设置中添加以下Secrets：

#### 必需的Secrets

```bash
# GitHub Container Registry (推荐)
GHCR_TOKEN=ghp_xxxxxxxxxxxx  # GitHub Personal Access Token

# 或者使用Docker Hub
DOCKERHUB_USERNAME=your_username
DOCKERHUB_TOKEN=dckr_pat_xxxxxxxxxxxx
```

#### 部署相关Secrets (可选)

```bash
# 测试环境
STAGING_SERVER_HOST=staging.example.com
STAGING_SERVER_USER=deploy
STAGING_SERVER_SSH_KEY=-----BEGIN OPENSSH PRIVATE KEY-----...
STAGING_SERVER_PORT=22

# 生产环境
PROD_SERVER_HOST=prod.example.com
PROD_SERVER_USER=deploy
PROD_SERVER_SSH_KEY=-----BEGIN OPENSSH PRIVATE KEY-----...
PROD_SERVER_PORT=22
```

### 第3步：修改镜像配置

编辑 `.github/workflows/*.yml` 文件，修改镜像名称：

```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}  # 会自动使用 username/repository
```

或者指定具体名称：

```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: your-username/miniblog
```

### 第4步：推送代码触发构建

```bash
git add .
git commit -m "Add GitHub Actions workflows"
git push origin main
```

## 使用方式

### 1. 自动构建

**触发条件:**

- 推送到 `main` 或 `develop` 分支
- 创建 `v*` 格式的标签
- 创建Pull Request

**查看构建:**

1. 访问GitHub仓库的 `Actions` 标签页
2. 查看工作流运行状态
3. 点击具体的运行查看详细日志

### 2. 手动部署

**步骤:**

1. 访问GitHub仓库的 `Actions` 标签页
2. 选择 `Manual Deploy` 工作流
3. 点击 `Run workflow`
4. 选择部署参数：
   - 环境: staging/production
   - 镜像标签: latest/v1.0.0/等
   - 部署模式: memory/mariadb
5. 点击 `Run workflow` 开始部署

### 3. 使用构建的镜像

**拉取镜像:**

```bash
# 从GitHub Container Registry拉取
docker pull ghcr.io/your-username/miniblog:latest

# 使用我们的部署脚本
./docker-deployment/scripts/deploy-from-github.sh -i your-username/miniblog -t latest
```

**直接运行:**

```bash
docker run -d \
  --name miniblog \
  -p 5555:5555 \
  -p 6666:6666 \
  ghcr.io/your-username/miniblog:latest
```

## 镜像标签策略

GitHub Actions会自动生成以下标签：

| 触发条件 | 生成的标签 | 示例 |
|----------|------------|------|
| push到main | `latest` | `ghcr.io/user/miniblog:latest` |
| push到develop | `develop` | `ghcr.io/user/miniblog:develop` |
| 创建tag v1.0.0 | `v1.0.0`, `1.0`, `1` | `ghcr.io/user/miniblog:v1.0.0` |
| push到feature分支 | `feature-branch-sha` | `ghcr.io/user/miniblog:feature-abc123` |

## 环境管理

### 配置环境

在GitHub仓库设置中创建环境：

1. 访问 `Settings` → `Environments`
2. 创建环境：`staging`, `production`
3. 为每个环境配置：
   - 部署分支限制
   - 环境Secrets
   - 审批规则（可选）

### 环境变量

每个环境可以有独立的配置：

```yaml
# staging环境
STAGING_SERVER_HOST: staging.example.com
STAGING_DB_PASSWORD: staging_password

# production环境  
PROD_SERVER_HOST: prod.example.com
PROD_DB_PASSWORD: production_password
```

## 安全扫描

工作流包含了Trivy安全扫描：

**功能:**

- 扫描Docker镜像中的已知漏洞
- 生成SARIF格式的报告
- 上传到GitHub Security标签页

**查看结果:**

1. 访问仓库的 `Security` 标签页
2. 查看 `Code scanning alerts`
3. 查看具体的漏洞详情和修复建议

## 监控和通知

### 工作流状态监控

**GitHub界面:**

- Actions标签页查看所有工作流
- 每个工作流的详细日志
- 失败时的错误信息

**徽章显示:**
在README中添加状态徽章：

```markdown
![Build Status](https://github.com/your-username/miniblog/workflows/Build%20and%20Deploy%20MiniBlog/badge.svg)
```

### 通知配置

**GitHub通知:**

- 工作流失败时自动发送邮件
- 可在GitHub设置中配置通知偏好

**Slack/Teams集成:**
可以添加通知步骤：

```yaml
- name: Notify Slack
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 故障排查

### 常见问题

1. **镜像推送失败**

   ```
   Error: denied: permission_denied
   ```

   **解决:** 检查GHCR_TOKEN权限，确保包含packages权限

2. **部署失败**

   ```
   Error: Host key verification failed
   ```

   **解决:** 检查SSH密钥配置，或在SSH命令中添加 `-o StrictHostKeyChecking=no`

3. **测试失败**

   ```
   Error: go test failed
   ```

   **解决:** 本地运行测试，修复失败的测试用例

### 调试技巧

**查看详细日志:**

1. 点击失败的工作流
2. 展开失败的步骤
3. 查看完整的错误信息

**本地复现:**

```bash
# 本地运行相同的命令
go test -v ./...
make build BINS=mb-apiserver
docker build -t test .
```

**调试模式:**
在工作流中添加调试步骤：

```yaml
- name: Debug info
  run: |
    echo "Current directory: $(pwd)"
    echo "Files: $(ls -la)"
    echo "Environment: $(env)"
```

## 最佳实践

### 1. 分支策略

- `main`: 生产环境代码
- `develop`: 开发环境代码
- `feature/*`: 功能分支
- `hotfix/*`: 紧急修复

### 2. 标签策略

- `v1.0.0`: 正式版本
- `v1.0.0-rc1`: 候选版本
- `v1.0.0-beta1`: 测试版本

### 3. 安全实践

- 使用最小权限的Token
- 定期轮换Secrets
- 启用分支保护规则
- 要求PR审查

### 4. 性能优化

- 使用缓存加速构建
- 并行运行独立的作业
- 只在必要时构建多架构镜像

这个GitHub Actions配置为你提供了完整的CI/CD流程，从代码提交到生产部署的全自动化。
