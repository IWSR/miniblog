<!--
 * @Author: your Name
 * @Date: 2025-09-13 10:40:47
 * @LastEditors: your Name
 * @LastEditTime: 2025-09-13 10:45:33
 * @Description: 
-->
# MiniBlog Docker 部署文件

这个目录包含了MiniBlog项目的完整Docker部署方案。

## 目录结构

```
docker-deployment/
├── README.md                    # 本文件，部署说明
├── configs/                     # 配置文件目录
│   ├── memory-db.yaml          # 内存数据库配置
│   └── mariadb.yaml            # MariaDB数据库配置
├── scripts/                     # 部署脚本目录
│   ├── build-image.sh          # 构建Docker镜像
│   ├── deploy-memory.sh        # 内存数据库部署
│   ├── deploy-mariadb.sh       # MariaDB数据库部署
│   ├── test-deployment.sh      # 部署测试脚本
│   └── manage.sh               # 服务管理脚本
└── docs/                        # 文档目录
    ├── deployment-guide.md     # 详细部署指南
    ├── docker-basics.md        # Docker基础知识
    └── troubleshooting.md      # 故障排查指南
```

## 快速开始

### 方案一：内存数据库（推荐新手）

```bash
cd docker-deployment
./scripts/deploy-memory.sh
```

### 方案二：MariaDB数据库（推荐生产）

```bash
cd docker-deployment  
./scripts/deploy-mariadb.sh
```

## 管理命令

```bash
# 查看服务状态
./scripts/manage.sh status

# 查看日志
./scripts/manage.sh logs

# 重启服务
./scripts/manage.sh restart

# 测试部署
./scripts/test-deployment.sh
```

## 文件说明

| 文件 | 用途 | 说明 |
|------|------|------|
| `scripts/build-image.sh` | 构建镜像 | 编译Go程序并构建Docker镜像 |
| `scripts/deploy-memory.sh` | 内存数据库部署 | 单容器，数据不持久化 |
| `scripts/deploy-mariadb.sh` | MariaDB部署 | 双容器，数据持久化 |
| `scripts/manage.sh` | 服务管理 | 启动、停止、重启、查看状态等 |
| `scripts/test-deployment.sh` | 部署测试 | 验证部署是否成功 |
| `configs/memory-db.yaml` | 内存数据库配置 | enable-memory-store: true |
| `configs/mariadb.yaml` | MariaDB配置 | enable-memory-store: false |

## 部署流程

1. **准备阶段**: 编译Go程序，构建Docker镜像
2. **部署阶段**: 启动容器，配置网络和存储
3. **验证阶段**: 测试API接口，确认部署成功
4. **管理阶段**: 日常运维，监控和维护
