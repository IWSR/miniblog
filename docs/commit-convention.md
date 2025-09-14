# Git 提交规范

## 概述

本项目采用 [Conventional Commits](https://www.conventionalcommits.org/) 规范来约束Git提交信息，确保提交历史清晰、易于理解和自动化处理。

## 提交信息格式

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### 基本格式示例

```
feat(auth): add user login functionality

Add JWT-based authentication system with login and logout endpoints.
Includes password hashing and token validation.

Closes #123
```

## 提交类型 (Type)

### 主要类型

| 类型 | 描述 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat(api): add user registration endpoint` |
| `fix` | 修复bug | `fix(auth): resolve token expiration issue` |
| `docs` | 文档更新 | `docs(readme): update installation guide` |
| `style` | 代码格式化 | `style(user): fix code formatting` |
| `refactor` | 代码重构 | `refactor(db): optimize database queries` |
| `test` | 测试相关 | `test(auth): add unit tests for login` |
| `chore` | 构建/工具相关 | `chore(deps): update dependencies` |

### 特殊类型

| 类型 | 描述 | 示例 |
|------|------|------|
| `perf` | 性能优化 | `perf(api): improve response time` |
| `ci` | CI/CD相关 | `ci(github): add automated deployment` |
| `build` | 构建系统 | `build(docker): optimize image size` |
| `revert` | 回滚提交 | `revert: feat(api): add user endpoint` |

## 作用域 (Scope)

作用域用于指明提交影响的模块或组件：

### MiniBlog项目作用域

| 作用域 | 描述 | 示例 |
|--------|------|------|
| `api` | API接口相关 | `feat(api): add user CRUD endpoints` |
| `auth` | 认证授权 | `fix(auth): resolve JWT validation` |
| `db` | 数据库相关 | `refactor(db): optimize user queries` |
| `docker` | Docker相关 | `chore(docker): update base image` |
| `config` | 配置文件 | `feat(config): add environment variables` |
| `middleware` | 中间件 | `feat(middleware): add request logging` |
| `model` | 数据模型 | `refactor(model): update user schema` |
| `service` | 业务逻辑 | `feat(service): add post service` |
| `handler` | 请求处理 | `fix(handler): handle validation errors` |
| `test` | 测试相关 | `test(auth): add integration tests` |
| `ci` | CI/CD | `ci(github): add security scanning` |
| `docs` | 文档 | `docs(api): update swagger documentation` |

## 描述 (Description)

- 使用现在时态："add" 而不是 "added" 或 "adds"
- 首字母小写
- 结尾不加句号
- 简洁明了，不超过50个字符

### 好的描述示例

```
✅ feat(auth): add JWT token validation
✅ fix(db): resolve connection timeout issue
✅ docs(readme): update deployment instructions
✅ refactor(api): simplify error handling logic
```

### 不好的描述示例

```
❌ feat(auth): Added JWT token validation.
❌ fix: fixed bug
❌ update readme
❌ refactor(api): This commit refactors the API error handling logic to make it more simple and easier to understand
```

## 正文 (Body)

- 可选，用于详细说明提交内容
- 与描述之间空一行
- 解释"什么"和"为什么"，而不是"怎么做"
- 每行不超过72个字符

### 示例

```
feat(api): add user profile update endpoint

Allow users to update their profile information including
name, email, and avatar. Includes validation for email
format and duplicate email checking.

The endpoint supports partial updates and returns the
updated user object with sensitive fields filtered out.
```

## 页脚 (Footer)

用于引用issue、破坏性变更等：

### 关闭Issue

```
Closes #123
Fixes #456
Resolves #789
```

### 破坏性变更

```
BREAKING CHANGE: API endpoint /users now requires authentication
```

### 多个引用

```
feat(api): add user search functionality

Add full-text search for users with pagination support.

Closes #123
Refs #456
```

## 完整示例

### 新功能

```
feat(auth): implement OAuth2 login

Add Google and GitHub OAuth2 authentication support.
Users can now login using their social media accounts
in addition to email/password authentication.

- Add OAuth2 configuration
- Implement callback handlers
- Update user model to support OAuth providers
- Add frontend login buttons

Closes #145
```

### Bug修复

```
fix(db): resolve connection pool exhaustion

Fix database connection pool not being properly released
after failed queries, which was causing connection
exhaustion under high load.

The issue was caused by missing connection.Close() calls
in error handling paths.

Fixes #234
```

### 文档更新

```
docs(deployment): add Docker deployment guide

Add comprehensive guide for deploying MiniBlog using
Docker and Docker Compose, including:

- Environment setup
- Configuration options
- Production deployment tips
- Troubleshooting guide
```

### 重构

```
refactor(service): extract user validation logic

Move user validation logic from handlers to a dedicated
service layer to improve code reusability and testability.

- Create UserValidationService
- Update all user-related handlers
- Add comprehensive unit tests
- Maintain backward compatibility
```

## 提交频率建议

### 推荐的提交粒度

- **一个提交一个逻辑变更**
- **功能完整但尽可能小**
- **可以独立测试和回滚**

### 示例

```bash
# 好的提交序列
git commit -m "feat(model): add User model"
git commit -m "feat(api): add user registration endpoint"
git commit -m "test(api): add user registration tests"
git commit -m "docs(api): document user registration API"

# 不好的提交
git commit -m "add user feature" # 太大，包含多个变更
git commit -m "fix typo" # 太小，应该合并到相关提交
```

## 分支命名规范

配合提交规范，分支命名也应该遵循一定规则：

```bash
# 功能分支
feature/user-authentication
feature/post-management
feature/oauth-integration

# 修复分支
fix/jwt-validation-bug
fix/database-connection-issue

# 文档分支
docs/api-documentation
docs/deployment-guide

# 重构分支
refactor/user-service
refactor/error-handling
```

## 工具集成

### 1. Commitizen

帮助生成规范的提交信息：

```bash
npm install -g commitizen cz-conventional-changelog
echo '{ "path": "cz-conventional-changelog" }' > ~/.czrc
```

使用：

```bash
git cz  # 代替 git commit
```

### 2. Commitlint

验证提交信息格式：

```bash
npm install --save-dev @commitlint/cli @commitlint/config-conventional
```

### 3. Husky

Git hooks管理：

```bash
npm install --save-dev husky
npx husky install
```

## 自动化检查

项目已配置自动化检查：

- **GitHub Actions**: 自动验证提交信息格式
- **Pre-commit hooks**: 本地提交前检查
- **PR检查**: Pull Request标题和描述检查

## 常见错误和修正

### 错误示例及修正

```bash
# ❌ 错误
git commit -m "update code"

# ✅ 正确
git commit -m "refactor(api): simplify error handling logic"

# ❌ 错误
git commit -m "Fix bug in user login"

# ✅ 正确
git commit -m "fix(auth): resolve JWT token validation issue"

# ❌ 错误
git commit -m "feat: Added new feature for user management and also fixed some bugs"

# ✅ 正确 (拆分为多个提交)
git commit -m "feat(user): add user profile management"
git commit -m "fix(user): resolve profile update validation"
```

## 提交信息模板

创建提交信息模板：

```bash
# 设置全局模板
git config --global commit.template ~/.gitmessage

# 创建模板文件
cat > ~/.gitmessage << 'EOF'
# <type>[optional scope]: <description>
# 
# [optional body]
# 
# [optional footer(s)]
# 
# Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert
# Scopes: api, auth, db, docker, config, middleware, model, service, handler, test, ci, docs
# 
# Examples:
# feat(auth): add JWT token validation
# fix(db): resolve connection timeout issue
# docs(readme): update installation guide
EOF
```

遵循这些规范将使项目的提交历史更加清晰，便于维护和自动化处理。
