#!/bin/bash

#==============================================================================
# PanBox Sync 管理脚本
# 版本：1.0
# 用途：安装、更新、重启、停止 PanBox Sync 文件同步系统
#
# 快速安装（国内用户推荐使用代理加速）：
#   # 方法 1: gh-proxy.org（推荐）
#   curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/deploy/panbox-sync.sh | sudo bash
#
#   # 方法 2: 原始地址
#   curl -fsSL https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/deploy/panbox-sync.sh | sudo bash
#
#   # 方法 3: 手动下载后执行（-O 参数强制覆盖）
#   wget -O panbox-sync.sh https://gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/deploy/panbox-sync.sh
#   sudo bash panbox-sync.sh
#==============================================================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
INSTALL_DIR="/opt/panbox-sync"
# 多个备用 URL，依次尝试（国内加速镜像 + 原始地址）
COMPOSE_URLS=(
    "https://gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/deploy/docker-compose.yml"
    "https://hk.gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/deploy/docker-compose.yml"
    "https://cdn.gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/deploy/docker-compose.yml"
    "https://edgeone.gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/deploy/docker-compose.yml"
    "https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/deploy/docker-compose.yml"
)
DOCKER_IMAGE="kokojacket/panbox-sync:latest"
START_PORT=8000
OPENLIST_START_PORT=5244

#==============================================================================
# 工具函数
#==============================================================================

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

#==============================================================================
# 检查函数
#==============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 权限运行此脚本"
        echo "使用方法: sudo bash panbox-sync.sh"
        exit 1
    fi
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "未检测到 Docker，请先安装 Docker"
        echo ""
        echo "安装方法："
        echo "  curl -fsSL https://get.docker.com | bash"
        exit 1
    fi
    print_success "Docker 已安装: $(docker --version)"
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "未检测到 Docker Compose，请先安装"
        echo ""
        echo "安装方法（Docker Compose V2）："
        echo "  已包含在 Docker 中，使用: docker compose"
        exit 1
    fi

    # 检测使用的是哪个版本
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        print_success "Docker Compose 已安装: $(docker-compose --version)"
    else
        DOCKER_COMPOSE_CMD="docker compose"
        print_success "Docker Compose 已安装: $(docker compose version)"
    fi
}

#==============================================================================
# Docker GID 检测函数
#==============================================================================

detect_docker_gid() {
    print_info "检测 docker 组 GID..."

    # 方法 1: getent (Linux)
    if command -v getent &> /dev/null; then
        DOCKER_GID=$(getent group docker | cut -d: -f3)
    # 方法 2: dscl (macOS)
    elif command -v dscl &> /dev/null; then
        DOCKER_GID=$(dscl . -read /Groups/docker PrimaryGroupID 2>/dev/null | awk '{print $2}')
    fi

    if [ -z "$DOCKER_GID" ]; then
        print_warning "无法自动检测 docker GID，使用默认值 999"
        DOCKER_GID=999
    else
        print_success "检测到 docker GID: $DOCKER_GID"
    fi
}

#==============================================================================
# 端口检测函数
#==============================================================================

check_port() {
    local port=$1
    if command -v ss &> /dev/null; then
        ss -tuln | grep -q ":$port " && return 1 || return 0
    elif command -v netstat &> /dev/null; then
        netstat -tuln | grep -q ":$port " && return 1 || return 0
    else
        # 如果没有 ss 或 netstat，尝试绑定端口测试
        (echo >/dev/tcp/127.0.0.1/$port) &> /dev/null && return 1 || return 0
    fi
}

find_available_port() {
    local port=$START_PORT
    while true; do
        if check_port $port; then
            echo $port
            return 0
        fi
        print_warning "端口 $port 已被占用，尝试下一个端口..."
        port=$((port + 1))

        # 防止无限循环，最多尝试 100 个端口
        if [ $port -gt $((START_PORT + 100)) ]; then
            print_error "无法找到可用端口（已尝试 $START_PORT - $port）"
            exit 1
        fi
    done
}

find_available_openlist_port() {
    local port=$OPENLIST_START_PORT
    while true; do
        if check_port $port; then
            echo $port
            return 0
        fi
        print_warning "OpenList 端口 $port 已被占用，尝试下一个端口..."
        port=$((port + 1))

        # 防止无限循环，最多尝试 100 个端口
        if [ $port -gt $((OPENLIST_START_PORT + 100)) ]; then
            print_error "无法找到可用的 OpenList 端口（已尝试 $OPENLIST_START_PORT - $port）"
            exit 1
        fi
    done
}

#==============================================================================
# IP 地址检测函数
#==============================================================================

get_public_ipv4() {
    # 获取 IPv4 公网地址
    local ip=""

    # 方法 1: ipify.org (强制 IPv4)
    ip=$(curl -4 -s --connect-timeout 3 https://api.ipify.org 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 2: ifconfig.me (强制 IPv4)
    ip=$(curl -4 -s --connect-timeout 3 https://ifconfig.me 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 3: icanhazip.com (强制 IPv4)
    ip=$(curl -4 -s --connect-timeout 3 https://icanhazip.com 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 4: ip.sb (强制 IPv4)
    ip=$(curl -4 -s --connect-timeout 3 https://api.ip.sb/ip 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi

    echo "无法获取"
}

get_public_ipv6() {
    # 获取 IPv6 公网地址
    local ip=""

    # 方法 1: ipify.org (强制 IPv6)
    ip=$(curl -6 -s --connect-timeout 3 https://api64.ipify.org 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ : ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 2: icanhazip.com (强制 IPv6)
    ip=$(curl -6 -s --connect-timeout 3 https://icanhazip.com 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ : ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 3: ip.sb (强制 IPv6)
    ip=$(curl -6 -s --connect-timeout 3 https://api.ip.sb/ip 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ : ]]; then
        echo "$ip"
        return 0
    fi

    echo "无法获取"
}

get_local_ipv4() {
    # 获取本地 IPv4 地址
    local ip=""

    # 方法 1: hostname -I (获取第一个 IPv4)
    if command -v hostname &> /dev/null; then
        ip=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | head -1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi

    # 方法 2: ip route (适用于现代 Linux)
    if command -v ip &> /dev/null; then
        ip=$(ip -4 route get 1 2>/dev/null | awk '{print $7; exit}')
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    fi

    # 方法 3: ifconfig (适用于旧版 Linux)
    if command -v ifconfig &> /dev/null; then
        ip=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1 | sed 's/addr://')
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    fi

    echo "无法获取"
}

get_local_ipv6() {
    # 获取本地 IPv6 地址
    local ip=""

    # 方法 1: hostname -I (获取第一个非本地 IPv6)
    if command -v hostname &> /dev/null; then
        ip=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E ':' | grep -v '^::1' | grep -v '^fe80:' | head -1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi

    # 方法 2: ip route (适用于现代 Linux)
    if command -v ip &> /dev/null; then
        ip=$(ip -6 route get 2001:4860:4860::8888 2>/dev/null | awk '{print $9; exit}')
        if [ -n "$ip" ] && [[ "$ip" =~ : ]] && [[ ! "$ip" =~ ^fe80: ]]; then
            echo "$ip"
            return 0
        fi
    fi

    # 方法 3: ifconfig (适用于旧版 Linux)
    if command -v ifconfig &> /dev/null; then
        ip=$(ifconfig 2>/dev/null | grep 'inet6' | grep -v '::1' | grep -v 'fe80:' | awk '{print $2}' | head -1 | sed 's/addr://')
        if [ -n "$ip" ] && [[ "$ip" =~ : ]]; then
            echo "$ip"
            return 0
        fi
    fi

    echo "无法获取"
}

#==============================================================================
# 下载函数（支持多个备用 URL 重试）
#==============================================================================

download_with_retry() {
    local output_file=$1
    shift  # 移除第一个参数，剩余的都是 URL 数组
    local urls=("$@")
    local count=1
    local total=${#urls[@]}

    for url in "${urls[@]}"; do
        # 提取代理名称或显示"原始地址"
        local source_name=""
        if echo "$url" | grep -q "gh-proxy.org"; then
            source_name="gh-proxy.org 代理"
        elif echo "$url" | grep -q "hk.gh-proxy.org"; then
            source_name="香港代理"
        elif echo "$url" | grep -q "cdn.gh-proxy.org"; then
            source_name="CDN 代理"
        elif echo "$url" | grep -q "edgeone.gh-proxy.org"; then
            source_name="EdgeOne 代理"
        else
            source_name="GitHub 原始地址"
        fi

        print_info "[$count/$total] 尝试下载: $source_name"

        if curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$output_file" 2>/dev/null; then
            print_success "配置文件下载成功"
            return 0
        else
            print_warning "下载失败，尝试下一个地址..."
        fi

        count=$((count + 1))
    done

    print_error "所有下载地址均失败，请检查网络连接或稍后重试"
    return 1
}

#==============================================================================
# .env 文件创建
#==============================================================================

create_env_file() {
    if [ ! -f "$INSTALL_DIR/.env" ]; then
        print_info "创建 .env 配置文件..."

        cat > "$INSTALL_DIR/.env" <<EOF
# Docker GID 配置（自动检测）
DOCKER_GID=$DOCKER_GID

# 端口配置（自动检测可用端口）
BACKEND_PORT=$AVAILABLE_PORT
OPENLIST_PORT=$AVAILABLE_OPENLIST_PORT

# 时区
TZ=Asia/Shanghai

# 内置 OpenList
ENABLE_INTERNAL_OPENLIST=true
EOF

        print_success ".env 文件创建完成"
    else
        # 如果 .env 已存在，更新 DOCKER_GID
        if grep -q "^DOCKER_GID=" "$INSTALL_DIR/.env"; then
            sed -i "s/^DOCKER_GID=.*/DOCKER_GID=$DOCKER_GID/" "$INSTALL_DIR/.env"
            print_success ".env 文件已更新（DOCKER_GID=$DOCKER_GID）"
        else
            echo "DOCKER_GID=$DOCKER_GID" >> "$INSTALL_DIR/.env"
            print_success ".env 文件已添加 DOCKER_GID"
        fi
    fi
}

#==============================================================================
# 安装函数
#==============================================================================

install_panbox() {
    print_header "安装 PanBox Sync"

    # 检查是否已安装
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_warning "检测到已安装 PanBox Sync"
        read -p "是否覆盖安装？[y/N]: " confirm < /dev/tty
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "取消安装"
            return 0
        fi
    fi

    # 创建目录
    print_info "创建数据目录..."
    mkdir -p "$INSTALL_DIR/data"
    mkdir -p "$INSTALL_DIR/openlist-data"

    # 设置目录权限（容器使用 UID 10001 运行）
    chown -R 10001:10001 "$INSTALL_DIR/data"
    chown -R 10001:10001 "$INSTALL_DIR/openlist-data"

    print_success "数据目录创建完成"

    # 检测 Docker GID
    detect_docker_gid

    # 下载 docker-compose.yml（自动尝试多个备用地址）
    print_info "下载配置文件..."
    if ! download_with_retry "$INSTALL_DIR/docker-compose.yml" "${COMPOSE_URLS[@]}"; then
        exit 1
    fi

    # 查找可用端口
    print_info "检测可用端口..."
    AVAILABLE_PORT=$(find_available_port)
    AVAILABLE_OPENLIST_PORT=$(find_available_openlist_port)
    print_success "端口检测完成"

    # 创建 .env 文件
    create_env_file

    # 拉取镜像
    print_info "拉取 Docker 镜像..."
    cd "$INSTALL_DIR"
    if docker pull "$DOCKER_IMAGE"; then
        print_success "镜像拉取成功"
    else
        print_error "镜像拉取失败"
        exit 1
    fi

    # 启动服务
    print_info "启动服务..."
    if $DOCKER_COMPOSE_CMD up -d; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败"
        exit 1
    fi

    # 等待服务启动
    print_info "等待服务健康检查..."
    sleep 5

    # 显示访问地址
    show_access_info "$AVAILABLE_PORT"
}

#==============================================================================
# 更新函数
#==============================================================================

update_panbox() {
    print_header "更新 PanBox Sync"

    # 检查是否已安装
    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_error "未检测到已安装的 PanBox Sync，请先执行安装"
        exit 1
    fi

    cd "$INSTALL_DIR"

    # 拉取最新镜像
    print_info "拉取最新镜像..."
    if docker pull "$DOCKER_IMAGE"; then
        print_success "镜像拉取成功"
    else
        print_error "镜像拉取失败"
        exit 1
    fi

    # 重启服务
    print_info "重启服务..."
    if $DOCKER_COMPOSE_CMD up -d; then
        print_success "服务更新成功"
    else
        print_error "服务更新失败"
        exit 1
    fi

    # 获取当前端口
    CURRENT_PORT=$(grep -oP 'BACKEND_PORT=\K[0-9]+' .env 2>/dev/null || echo "8000")

    # 显示访问地址
    show_access_info "$CURRENT_PORT"
}

#==============================================================================
# 重启函数
#==============================================================================

restart_panbox() {
    print_header "重启 PanBox Sync"

    # 检查是否已安装
    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_error "未检测到已安装的 PanBox Sync，请先执行安装"
        exit 1
    fi

    cd "$INSTALL_DIR"

    print_info "重启服务..."
    if $DOCKER_COMPOSE_CMD restart; then
        print_success "服务重启成功"
    else
        print_error "服务重启失败"
        exit 1
    fi

    # 获取当前端口
    CURRENT_PORT=$(grep -oP 'BACKEND_PORT=\K[0-9]+' .env 2>/dev/null || echo "8000")

    # 显示访问地址
    show_access_info "$CURRENT_PORT"
}

#==============================================================================
# 停止函数
#==============================================================================

stop_panbox() {
    print_header "停止 PanBox Sync"

    # 检查是否已安装
    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_error "未检测到已安装的 PanBox Sync"
        exit 1
    fi

    cd "$INSTALL_DIR"

    print_info "停止服务..."
    if $DOCKER_COMPOSE_CMD down; then
        print_success "服务已停止"
    else
        print_error "服务停止失败"
        exit 1
    fi
}

#==============================================================================
# 显示访问信息
#==============================================================================

show_access_info() {
    local backend_port=$1

    print_header "访问地址"

    # 获取公网 IPv4
    print_info "正在获取公网 IPv4..."
    PUBLIC_IPV4=$(get_public_ipv4)

    # 获取公网 IPv6
    print_info "正在获取公网 IPv6..."
    PUBLIC_IPV6=$(get_public_ipv6)

    # 获取内网 IPv4（内网只显示 IPv4）
    print_info "正在获取内网 IP..."
    LOCAL_IPV4=$(get_local_ipv4)

    echo -e "${GREEN}🎉 PanBox Sync 部署成功！${NC}"
    echo ""
    echo "访问地址："

    # 显示公网 IPv4
    if [ "$PUBLIC_IPV4" != "无法获取" ]; then
        echo -e "  ${BLUE}http://$PUBLIC_IPV4:$backend_port${NC}"
    fi

    # 显示公网 IPv6
    if [ "$PUBLIC_IPV6" != "无法获取" ]; then
        echo -e "  ${BLUE}http://[$PUBLIC_IPV6]:$backend_port${NC}"
    fi

    # 如果两个公网 IP 都获取失败
    if [ "$PUBLIC_IPV4" = "无法获取" ] && [ "$PUBLIC_IPV6" = "无法获取" ]; then
        echo -e "  ${YELLOW}公网 IP: 无法获取（纯内网环境）${NC}"
    fi

    # 显示内网 IPv4
    if [ "$LOCAL_IPV4" != "无法获取" ]; then
        echo -e "  ${BLUE}http://$LOCAL_IPV4:$backend_port${NC}"
    else
        echo -e "  ${YELLOW}内网 IP: 无法获取${NC}"
    fi

    echo ""

    # 根据获取到的 IP 类型给出不同提示
    if [ "$PUBLIC_IPV6" != "无法获取" ] && [ "$PUBLIC_IPV4" = "无法获取" ]; then
        echo -e "${YELLOW}提示：${NC}"
        echo -e "  - 当前服务器仅有 IPv6 公网地址"
        echo -e "  - IPv6 地址需要用方括号 [] 包裹"
        echo -e "  - 建议使用内网 IPv4 地址访问（兼容性更好）"
        echo ""
    elif [ "$PUBLIC_IPV4" != "无法获取" ] && [ "$PUBLIC_IPV6" != "无法获取" ]; then
        echo -e "${YELLOW}提示：${NC}"
        echo -e "  - 优先使用 IPv4 地址访问（兼容性更好）"
        echo -e "  - IPv6 地址需要用方括号 [] 包裹"
        echo ""
    fi

    echo -e "${YELLOW}首次使用提示：${NC}"
    echo -e "  - 请在 PanBox Sync 界面注册账号"
    echo -e "  - 激活后即可登录使用"
    echo ""
}

#==============================================================================
# 主菜单
#==============================================================================

show_menu() {
    clear

    cat <<'EOF'
  ____              ____
 |  _ \ __ _ _ __ | __ )  _____  __
 | |_) / _` | '_ \|  _ \ / _ \ \/ /
 |  __/ (_| | | | | |_) | (_) >  <
 |_|   \__,_|_| |_|____/ \___/_/\_\

       文件同步系统 - 管理脚本
            Version 1.0
EOF

    echo ""
    echo -e "${BLUE}请选择操作：${NC}"
    echo "  1) 安装 PanBox Sync"
    echo "  2) 更新 PanBox Sync"
    echo "  3) 重启 PanBox Sync"
    echo "  4) 停止 PanBox Sync"
    echo "  0) 退出"
    echo ""
}

#==============================================================================
# 主流程
#==============================================================================

main() {
    # 检查环境
    check_root
    check_docker
    check_docker_compose

    while true; do
        show_menu
        read -p "请输入选项 [0-4]: " choice < /dev/tty

        case $choice in
            1)
                install_panbox
                read -p "按 Enter 键返回菜单..." < /dev/tty
                ;;
            2)
                update_panbox
                read -p "按 Enter 键返回菜单..." < /dev/tty
                ;;
            3)
                restart_panbox
                read -p "按 Enter 键返回菜单..." < /dev/tty
                ;;
            4)
                stop_panbox
                read -p "按 Enter 键返回菜单..." < /dev/tty
                ;;
            0)
                print_info "退出脚本"
                exit 0
                ;;
            *)
                print_error "无效选项，请输入 0-4"
                sleep 2
                ;;
        esac
    done
}

# 运行主函数
main
