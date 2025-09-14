# MiniBlog GitHub Actions 部署流程

## 完整部署架构图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   开发者本地     │    │   GitHub        │    │   生产服务器     │
│                │    │                │    │                │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │ 代码提交   │  │───▶│  │ Actions   │  │───▶│  │ 自动部署   │  │
│  └───────────┘  │    │  │ 工作流     │  │    │  └───────────┘  │
│                │    │  └───────────┘  │    │                │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │ 推送代码   │  │    │  │ 构建镜像   │  │    │  │ 运行容器   │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
│                │    │  ┌───────────┐  │    │                │
└─────────────────┘    │  │ 推送镜像   │  │    └─────────────────┘
                       │  └───────────┘  │
                       └─────────────────┘
```

## 详细部署流程

### 阶段1：代码提交触发

```
开发者操作          GitHub事件           触发条件
─────────────────────────────────────────────────
git push origin main    → push事件      → 构建latest镜像
git push origin develop → push事件      → 构建develop镜像  
git tag v1.0.0         → tag事件       → 构建版本镜像
创建Pull Request       → PR事件        → 代码质量检查
```

### 阶段2：GitHub Actions执行

```
步骤                    执行内容                     输出
──────────────────────────────────────────────────────────
1. 代码检出            checkout代码                  源代码
2. Go环境设置          安装Go 1.23.4               Go环境
3. 依赖下载            go mod download              依赖包
4. 代码测试            go test ./...                测试结果
5. 代码编译            make build BINS=mb-apiserver  二进制文件
6. Docker构建          docker build                 Docker镜像
7. 镜像推送            docker push                  GHCR镜像
8. 安全扫描            trivy scan                   安全报告
9. 服务器部署          SSH执行部署脚本               运行容器
```

### 阶段3：服务器部署执行

```
服务器操作              执行命令                      结果
─────────────────────────────────────────────────────────
1. 登录容器注册表       docker login ghcr.io         认证成功
2. 拉取最新镜像        docker pull image:tag         本地镜像
3. 停止旧容器          docker stop old-container     容器停止
4. 删除旧容器          docker rm old-container       容器删除
5. 创建配置文件        cat > config.yaml             配置文件
6. 启动新容器          docker run new-container      容器运行
7. 健康检查            curl /healthz                 服务就绪
```

## 配置要求总览

### GitHub端配置

```yaml
必需的Secrets:
├── GHCR_TOKEN                 # GitHub容器注册表访问令牌
├── PROD_SERVER_HOST          # 生产服务器IP/域名
├── PROD_SERVER_USER          # 服务器用户名
├── PROD_SERVER_SSH_KEY       # SSH私钥
└── PROD_SERVER_PORT          # SSH端口(可选,默认22)

可选的Secrets:
├── STAGING_SERVER_HOST       # 测试服务器配置
├── STAGING_SERVER_USER       
├── STAGING_SERVER_SSH_KEY    
└── STAGING_SERVER_PORT       
```

### 服务器端配置

```bash
必需的软件:
├── Docker                    # 容器运行时
├── Docker Compose           # 容器编排(可选)
├── UFW防火墙                # 安全防护
└── Fail2Ban                 # 入侵防护

必需的配置:
├── 部署用户(deploy)          # 专用部署账户
├── SSH密钥认证              # 无密码登录
├── Docker权限               # 用户加入docker组
└── 防火墙规则               # 开放必要端口
```

## 部署模式对比

### 内存数据库模式

```
特点:
├── 单容器部署               # 只需要应用容器
├── 数据存储在内存           # 重启后数据丢失
├── 资源占用低               # ~256MB内存
└── 适合开发测试             # 快速启动

部署命令:
docker run -d \
  --name miniblog-app \
  -p 5555:5555 \
  -p 6666:6666 \
  ghcr.io/user/miniblog:latest
```

### MariaDB数据库模式

```
特点:
├── 双容器部署               # 应用+数据库容器
├── 数据持久化存储           # 数据永久保存
├── 资源占用中等             # ~768MB内存
└── 适合生产环境             # 稳定可靠

部署命令:
# 1. 启动数据库
docker run -d --name miniblog-mariadb \
  -e MYSQL_ROOT_PASSWORD=root123456 \
  -v miniblog-db-data:/var/lib/mysql \
  mariadb:10.11

# 2. 启动应用
docker run -d --name miniblog-app \
  --link miniblog-mariadb \
  -p 5555:5555 \
  ghcr.io/user/miniblog:latest
```

## 端口分配策略

### 生产环境端口

```
服务                    端口        用途
─────────────────────────────────────────
MiniBlog HTTP          5555        REST API
MiniBlog gRPC          6666        gRPC服务
MariaDB                3306        数据库连接
SSH                    22          服务器管理
```

### 测试环境端口

```
服务                    端口        用途
─────────────────────────────────────────
MiniBlog HTTP          5556        REST API
MiniBlog gRPC          6667        gRPC服务  
MariaDB                3307        数据库连接
SSH                    22          服务器管理
```

## 工作流触发策略

### 自动触发

```yaml
触发事件:
├── push到main分支           → 构建并部署到生产环境
├── push到develop分支        → 构建并部署到测试环境
├── 创建v*标签              → 构建版本镜像并发布
└── 创建Pull Request        → 代码质量检查
```

### 手动触发

```yaml
手动部署选项:
├── 选择环境: production/staging
├── 选择镜像标签: latest/v1.0.0/develop
├── 选择部署模式: memory/mariadb
└── 一键执行部署
```

## 监控和日志

### GitHub Actions监控

```
监控项目:
├── 工作流执行状态           # 成功/失败状态
├── 构建时间                # 性能监控
├── 测试覆盖率              # 代码质量
└── 安全扫描结果            # 漏洞检测
```

### 服务器监控

```bash
监控命令:
├── docker ps               # 容器状态
├── docker logs -f app      # 应用日志
├── docker stats            # 资源使用
└── curl /healthz           # 健康检查
```

## 故障恢复流程

### 部署失败恢复

```bash
1. 查看GitHub Actions日志
   → 定位失败原因

2. 检查服务器状态
   → ssh到服务器检查

3. 手动回滚
   → 启动上一个版本容器

4. 修复问题后重新部署
   → 推送修复代码触发重新部署
```

### 服务异常恢复

```bash
1. 检查容器状态
   docker ps -a

2. 查看容器日志
   docker logs miniblog-app

3. 重启容器
   docker restart miniblog-app

4. 如果无法恢复，重新部署
   手动触发GitHub Actions部署
```

## 安全考虑

### 网络安全

```bash
防护措施:
├── UFW防火墙               # 只开放必要端口
├── Fail2Ban               # 防止暴力破解
├── SSH密钥认证            # 禁用密码登录
└── 定期更新系统           # 安全补丁
```

### 应用安全

```yaml
安全配置:
├── 非root用户运行          # 容器安全
├── 最小权限原则           # 用户权限
├── 定期扫描镜像           # 漏洞检测
└── HTTPS配置              # 传输加密
```

这个部署流程确保了从代码提交到生产部署的全自动化，同时保证了安全性和可靠性。
