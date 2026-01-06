#!/bin/bash

# PanBox Sync 一键安装脚本（Linux/macOS）

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   PanBox Sync 一键安装脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: 未检测到 Docker，请先安装 Docker${NC}"
    echo "安装文档: https://docs.docker.com/get-docker/"
    exit 1
fi

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}错误: 未检测到 Docker Compose，请先安装${NC}"
    echo "安装文档: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${GREEN}✓ Docker 环境检查通过${NC}"
echo ""

# 创建安装目录
INSTALL_DIR="${1:-./panbox-sync}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo -e "${BLUE}安装目录: $(pwd)${NC}"
echo ""

# 下载配置文件
echo -e "${BLUE}正在下载配置文件...${NC}"
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/.env.example

# 创建 .env 文件
if [ ! -f .env ]; then
    echo -e "${YELLOW}请配置环境变量...${NC}"
    cp .env.example .env

    # 生成随机密钥
    SECRET_KEY=$(openssl rand -hex 32)
    sed -i.bak "s/your_secret_key_here_please_change_me/$SECRET_KEY/" .env

    echo -e "${YELLOW}请编辑 .env 文件，配置以下必需项：${NC}"
    echo "  - DB_PASSWORD: 数据库密码"
    echo "  - OPENLIST_URL: OpenList 服务器地址"
    echo ""
    echo -e "${YELLOW}按回车键继续编辑 .env 文件...${NC}"
    read -r
    ${EDITOR:-vim} .env
fi

echo -e "${GREEN}✓ 配置文件准备完成${NC}"
echo ""

# 拉取镜像
echo -e "${BLUE}正在拉取 Docker 镜像...${NC}"
docker-compose pull

# 启动服务
echo -e "${BLUE}正在启动服务...${NC}"
docker-compose up -d

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "访问地址: ${BLUE}http://localhost:8000${NC}"
echo ""
echo "常用命令:"
echo "  查看日志: docker-compose logs -f"
echo "  停止服务: docker-compose stop"
echo "  启动服务: docker-compose start"
echo "  重启服务: docker-compose restart"
echo "  卸载服务: docker-compose down -v"
echo ""
