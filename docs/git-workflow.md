# Git 工作流程和提交规范

## 概述

MiniBlog项目采用规范化的Git工作流程，包括分支管理、提交信息规范和自动化检查。

## 分支策略

### 主要分支

```
main (生产分支)
├── develop (开发分支)
├── feature/* (功能分支)
├── fix/* (修复分支)
├── hotfix/* (紧急修复)
└── release/* (发布分支)
```

### 分支说明

| 分支类型 | 命名规范 | 用途 | 示例 |
|----------|----------|------|------|
| `main` | 固定名称 | 生产环境代码 | `main` |
| `develop` | 固定名称 | 开发环境代码 | `develop` |
| `feature` | `feature/功能名` | 新功能开发 | `feature/user-auth` |
| `fix` | `fix/问题描述` | Bug修复 | `fix/login-timeout` |
| `hotfix` | `hotfix/紧急修复` | 生产环境紧急修复 | `hotfix/security-patch` |
| `release` | `release/版本号` | 发布准备 | `release/v1.2.0` |

## 提交信息规范

### 格式要求

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### 类型说明

| 类型 | 描述 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat(auth): add OAuth2 login` |
| `fix` | 修复bug | `fix(db): resolve connection pool leak` |
| `docs` | 文档更新 | `docs(api): update endpoint documentation` |
| `style` | 代码格式 | `style(handler): fix code formatting` |
| `refactor` | 重构 | `refactor(service): extract validation logic` |
| `test` | 测试 | `test(auth): add unit tests for JWT` |
| `chore` | 构建/工具 | `chore(deps): update Go dependencies` |
| `perf` | 性能优化 | `perf(db): optimize query performance` |
| `ci` | CI/CD | `ci(github): add security scanning` |
| `build` | 构建系统 | `build(docker): optimize image layers` |
| `revert` | 回滚 | `revert: feat(auth): add OAuth2 login` |

### 作用域说明

| 作用域 | 描述 | 示例 |
|--------|------|------|
| `api` | API接口 | `feat(api): add user search endpoint` |
| `auth` | 认证授权 | `fix(auth): resolve token refresh issue` |
| `db` | 数据库 | `perf(db): add database indexes` |
| `docker` | Docker相关 | `chore(docker): update base image` |
| `config` | 配置 | `feat(config): add environment validation` |
| `middleware` | 中间件 | `feat(middleware): add rate limiting` |
| `model` | 数据模型 | `refactor(model): update user schema` |
| `service` | 业务逻辑 | `feat(service): add post service` |
| `handler` | 请求处理 | `fix(handler): improve error handling` |
| `test` | 测试 | `test(service): add integration tests` |
| `ci` | CI/CD | `ci(github): add automated deployment` |
| `docs` | 文档 | `docs(readme): update installation guide` |

## 工作流程

### 功能开发流程

```bash
# 1. 从develop分支创建功能分支
git checkout develop
git pull origin develop
git checkout -b feature/user-profile

# 2. 开发功能，规范提交
git add .
git commit -m "feat(user): add profile update endpoint"

# 3. 推送分支
git push origin feature/user-profile

# 4. 创建Pull Request到develop分支
# 5. 代码审查通过后合并
# 6. 删除功能分支
git branch -d feature/user-profile
```

### 修复Bug流程

```bash
# 1. 从相应分支创建修复分支
git checkout develop  # 或 main（如果是hotfix）
git pull origin develop
git checkout -b fix/login-validation

# 2. 修复问题
git add .
git commit -m "fix(auth): resolve login validation issue"

# 3. 推送并创建PR
git push origin fix/login-validation
```

### 发布流程

```bash
# 1. 从develop创建发布分支
git checkout develop
git pull origin develop
git checkout -b release/v1.2.0

# 2. 准备发布（更新版本号、文档等）
git commit -m "chore(release): prepare v1.2.0"

# 3. 合并到main并打标签
git checkout main
git merge release/v1.2.0
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin main --tags

# 4. 合并回develop
git checkout develop
git merge release/v1.2.0
git push origin develop

# 5. 删除发布分支
git branch -d release/v1.2.0
```

## 自动化检查

### Pre-commit检查

每次提交前自动执行：

- 代码格式检查（gofmt）
- 提交信息格式验证
- 大文件检查

### GitHub Actions检查

Pull Request时自动执行：

- 提交信息规范检查
- 代码质量检查
- 单元测试
- 构建验证

### 提交信息验证

使用commitlint自动验证：

- 格式正确性
- 类型有效性
- 作用域规范性
- 描述长度限制

## 工具使用

### 安装和配置

```bash
# 快速设置（推荐）
chmod +x scripts/quick-setup-commit-rules.sh
./scripts/quick-setup-commit-rules.sh

# 或完整设置
chmod +x scripts/setup-git-hooks.sh
./scripts/setup-git-hooks.sh
```

### 日常使用

```bash
# 交互式提交（推荐）
git add .
git cz

# 或使用别名
git add .
git cz

# 普通提交
git commit -m "feat(auth): add user registration"

# 查看提交历史
git lg  # 使用配置的别名
```

### 验证提交信息

```bash
# 本地验证
echo "feat(auth): add login" | npx commitlint

# 验证最近的提交
npx commitlint --from HEAD~1 --to HEAD --verbose
```

## 最佳实践

### 提交频率

- **小而频繁的提交**：每个提交包含一个逻辑变更
- **完整的功能**：确保每个提交都是可工作的状态
- **原子性**：一个提交只做一件事

### 提交信息质量

```bash
# ✅ 好的提交信息
feat(auth): add JWT token validation middleware
fix(db): resolve connection timeout in user queries
docs(api): update authentication endpoint documentation

# ❌ 不好的提交信息
update code
fix bug
add feature
```

### 分支管理

- **及时清理**：合并后删除功能分支
- **保持同步**：定期从主分支拉取更新
- **描述性命名**：分支名要能说明其用途

### 代码审查

- **小的PR**：每个PR包含有限的变更
- **清晰的描述**：PR描述要说明变更内容和原因
- **及时响应**：快速响应审查意见

## 故障排查

### 提交被拒绝

```bash
# 查看具体错误
git commit -m "invalid message"
# 会显示具体的格式错误

# 修改最后一次提交信息
git commit --amend -m "feat(auth): add user login"
```

### Hook不工作

```bash
# 重新安装hooks
npx husky install
npx husky add .husky/commit-msg 'npx --no-install commitlint --edit "$1"'

# 检查hook权限
chmod +x .husky/commit-msg
```

### 配置问题

```bash
# 检查commitlint配置
npx commitlint --print-config

# 测试配置
echo "feat: test" | npx commitlint
```

## 参考资源

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Commitlint](https://commitlint.js.org/)
- [Husky](https://typicode.github.io/husky/)
- [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/)

遵循这些规范将使项目的版本控制更加规范和高效。
