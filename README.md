# PanBox Sync - 部署仓库

这是 PanBox Sync 的公开部署仓库，包含 Docker Compose 配置、一键安装脚本等。

## 快速开始

### 使用 Docker Compose

```bash
# 下载 docker-compose.yml
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/panbox-sync-deploy/main/docker-compose.yml

# 启动服务
docker-compose up -d
```

### 一键安装脚本

```bash
# Linux/macOS
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/panbox-sync-deploy/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/YOUR_USERNAME/panbox-sync-deploy/main/install.ps1 | iex
```

## 环境变量

在启动前，请配置以下环境变量（或创建 `.env` 文件）：

```bash
# 数据库配置
DB_USER=panbox
DB_PASSWORD=your_secure_password
DB_NAME=panbox_sync

# 应用配置
SECRET_KEY=your_secret_key_here
OPENLIST_URL=https://your-openlist-server.com
```

## 目录结构

```
.
├── docker-compose.yml       # Docker Compose 配置
├── install.sh               # Linux/macOS 安装脚本
├── install.ps1              # Windows 安装脚本
├── .env.example             # 环境变量示例
└── README.md                # 本文件
```

## 文档

- [完整文档](https://github.com/YOUR_USERNAME/panbox-sync)
- [问题反馈](https://github.com/YOUR_USERNAME/panbox-sync/issues)

## 许可证

MIT License
