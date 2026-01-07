# PanBox Sync 部署指南

> 🚀 一键部署 PanBox Sync 文件同步系统

## 快速开始

### 方法 1：一键安装（推荐）

使用 gh-proxy.org 代理（国内用户推荐）：

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/kokojacket/openlist-sync/main/deploy/panbox-sync.sh | sudo bash
```

或使用原始地址：

```bash
curl -fsSL https://raw.githubusercontent.com/kokojacket/openlist-sync/main/deploy/panbox-sync.sh | sudo bash
```

### 方法 2：手动下载安装

```bash
# 下载部署脚本
wget https://gh-proxy.org/https://raw.githubusercontent.com/kokojacket/openlist-sync/main/deploy/panbox-sync.sh

# 运行脚本
sudo bash panbox-sync.sh
```

### 方法 3：克隆仓库部署

```bash
# 克隆仓库
git clone https://github.com/kokojacket/openlist-sync.git
cd openlist-sync/deploy

# 运行部署脚本
sudo bash panbox-sync.sh
```

## 系统要求

- **操作系统**：Linux（Ubuntu/Debian/CentOS）或 macOS
- **Docker**：20.10 或更高版本
- **Docker Compose**：V2（推荐）或 V1
- **权限**：需要 root 权限（用于创建目录和修改权限）

## 功能特性

### 部署脚本功能

- ✅ **自动环境检测**：检查 Docker 和 Docker Compose 安装
- ✅ **自动 GID 检测**：自动检测宿主机 docker 组 GID，无需手动配置
- ✅ **端口冲突检测**：自动查找可用端口（默认从 8000 开始）
- ✅ **IP 地址获取**：自动获取公网 IPv4/IPv6 和内网 IPv4 地址
- ✅ **菜单式操作**：安装、更新、重启、停止一体化管理
- ✅ **多镜像源支持**：自动尝试多个 GitHub 代理，适合国内网络
- ✅ **健康检查**：服务启动后自动验证运行状态

### 应用功能

- ✅ **文件同步**：OpenList 到 OpenList 的文件同步
- ✅ **MD5 修改**：自动修改文件 MD5，避免重复检测
- ✅ **流水线架构**：下载 → 转码 → 上传三阶段并行处理
- ✅ **实时进度**：SSE 实时推送文件传输进度
- ✅ **崩溃恢复**：服务重启后自动恢复未完成的任务
- ✅ **内置 OpenList**：一体化部署，无需额外配置 OpenList

## 使用说明

### 运行部署脚本

```bash
sudo bash panbox-sync.sh
```

### 菜单选项

```
  ____              ____
 |  _ \ __ _ _ __ | __ )  _____  __
 | |_) / _` | '_ \|  _ \ / _ \ \/ /
 |  __/ (_| | | | | |_) | (_) >  <
 |_|   \__,_|_| |_|____/ \___/_/\_\

       文件同步系统 - 管理脚本
            Version 1.0

请选择操作：
  1) 安装 PanBox Sync
  2) 更新 PanBox Sync
  3) 重启 PanBox Sync
  4) 停止 PanBox Sync
  0) 退出
```

### 操作说明

#### 1. 安装

- 自动检测并配置 docker GID
- 下载 docker-compose.yml 配置文件
- 创建数据目录并设置权限
- 拉取 Docker 镜像
- 启动服务
- 显示访问地址

#### 2. 更新

- 拉取最新 Docker 镜像
- 重启服务应用更新
- 保留所有数据和配置

#### 3. 重启

- 重启所有服务
- 不拉取新镜像
- 适用于配置修改后生效

#### 4. 停止

- 停止所有服务
- 保留数据和配置
- 可随时再次启动

## 配置说明

### 自动生成的配置

部署脚本会自动创建 `/opt/panbox-sync/.env` 文件，包含以下配置：

```bash
# Docker GID（自动检测）
DOCKER_GID=999

# 端口配置
BACKEND_PORT=8000
OPENLIST_PORT=5244

# 时区
TZ=Asia/Shanghai

# 内置 OpenList
ENABLE_INTERNAL_OPENLIST=true
INTERNAL_OPENLIST_PORT=5244
```

### 手动配置（可选）

如需修改配置，编辑 `/opt/panbox-sync/.env` 文件：

```bash
# 编辑配置
sudo nano /opt/panbox-sync/.env

# 重启服务使配置生效
cd /opt/panbox-sync
sudo docker-compose restart
```

### 配置项说明

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `DOCKER_GID` | Docker 组 GID（自动检测） | 999 |
| `BACKEND_PORT` | PanBox Sync 后端端口 | 8000 |
| `OPENLIST_PORT` | 内置 OpenList 端口 | 5244 |
| `TZ` | 时区 | Asia/Shanghai |
| `ENABLE_INTERNAL_OPENLIST` | 启用内置 OpenList | true |
| `INTERNAL_OPENLIST_PORT` | 内置 OpenList 端口 | 5244 |

## 数据目录

部署脚本会在 `/opt/panbox-sync/` 创建以下目录结构：

```
/opt/panbox-sync/
├── docker-compose.yml    # Docker Compose 配置
├── .env                  # 环境变量配置（自动生成）
├── data/                 # 应用数据目录
│   ├── database.db      # SQLite 数据库
│   ├── downloads/       # 下载临时目录
│   ├── uploads/         # 上传临时目录
│   └── logs/            # 日志文件
└── openlist-data/        # 内置 OpenList 数据目录
```

### 目录权限

- **所有者**：UID 10001（容器内的 panbox 用户）
- **权限**：755（读写执行）

如需修复权限问题：

```bash
sudo chown -R 10001:10001 /opt/panbox-sync/data
sudo chown -R 10001:10001 /opt/panbox-sync/openlist-data
sudo chmod -R 755 /opt/panbox-sync/data
sudo chmod -R 755 /opt/panbox-sync/openlist-data
```

## 首次使用

### 1. 访问 Web 界面

部署完成后，脚本会显示访问地址：

```
🎉 PanBox Sync 部署成功！

访问地址：
  http://your-ip:8000

首次使用提示：
  - 请在 PanBox Sync 界面注册账号
  - 激活后即可登录使用
```

### 2. 注册账号

1. 打开浏览器访问显示的地址
2. 点击"注册"按钮
3. 填写用户名、邮箱、密码
4. 提交注册

### 3. 激活账号

- 注册后系统会发送激活邮件
- 或联系管理员激活

### 4. 登录使用

- 使用注册的用户名和密码登录
- 开始配置同步任务

## 常见问题

### Q1：部署脚本无法下载配置文件

**问题**：网络超时或连接失败

**解决**：
1. 脚本会自动尝试多个镜像源
2. 如全部失败，请检查网络连接
3. 或手动下载 docker-compose.yml 到 `/opt/panbox-sync/`

### Q2：端口被占用

**问题**：默认端口 8000 已被占用

**解决**：
- 脚本会自动检测并使用下一个可用端口（8001, 8002...）
- 或手动修改 `.env` 中的 `BACKEND_PORT`

### Q3：权限错误

**问题**：容器无法写入数据目录

**解决**：
```bash
sudo chown -R 10001:10001 /opt/panbox-sync/data
sudo chown -R 10001:10001 /opt/panbox-sync/openlist-data
sudo chmod -R 755 /opt/panbox-sync/data
sudo chmod -R 755 /opt/panbox-sync/openlist-data
sudo docker-compose restart
```

### Q4：如何查看日志

**应用日志**：
```bash
# 查看容器日志
sudo docker logs -f panbox-sync

# 查看应用日志文件
sudo tail -f /opt/panbox-sync/data/logs/app.log

# 查看 OpenList 日志
sudo tail -f /opt/panbox-sync/data/logs/openlist.log
```

### Q5：如何备份数据

**备份命令**：
```bash
# 停止服务
cd /opt/panbox-sync
sudo docker-compose down

# 备份数据目录
sudo tar -czf panbox-sync-backup-$(date +%Y%m%d).tar.gz \
  /opt/panbox-sync/data \
  /opt/panbox-sync/openlist-data \
  /opt/panbox-sync/.env

# 重启服务
sudo docker-compose up -d
```

**恢复数据**：
```bash
# 停止服务
cd /opt/panbox-sync
sudo docker-compose down

# 解压备份
sudo tar -xzf panbox-sync-backup-YYYYMMDD.tar.gz -C /

# 修复权限
sudo chown -R 10001:10001 /opt/panbox-sync/data
sudo chown -R 10001:10001 /opt/panbox-sync/openlist-data

# 重启服务
sudo docker-compose up -d
```

### Q6：如何卸载

```bash
# 停止并删除容器
cd /opt/panbox-sync
sudo docker-compose down -v

# 删除数据目录（⚠️ 会删除所有数据）
sudo rm -rf /opt/panbox-sync

# 删除 Docker 镜像（可选）
sudo docker rmi kokojacket/panbox-sync:latest
```

## 升级指南

### 从旧版本升级

如果你使用的是旧版本（PostgreSQL 架构），需要迁移数据：

1. **备份旧版本数据**：
   ```bash
   # 导出 PostgreSQL 数据
   docker exec panbox-sync-db pg_dump -U panbox panbox_sync > backup.sql
   ```

2. **停止旧版本**：
   ```bash
   cd /path/to/old/deployment
   sudo docker-compose down
   ```

3. **部署新版本**：
   ```bash
   sudo bash panbox-sync.sh
   # 选择 "1) 安装 PanBox Sync"
   ```

4. **数据迁移**：
   - 新版本使用 SQLite，数据结构有变化
   - 需要手动重新配置同步任务
   - 或联系开发者获取迁移脚本

### 更新到最新版本

```bash
sudo bash panbox-sync.sh
# 选择 "2) 更新 PanBox Sync"
```

更新过程：
1. 拉取最新 Docker 镜像
2. 重启服务应用更新
3. 保留所有数据和配置

## 技术支持

- **GitHub Issues**：https://github.com/kokojacket/openlist-sync/issues
- **文档**：https://github.com/kokojacket/openlist-sync/tree/main/docs

## 许可证

本项目采用 MIT 许可证。
