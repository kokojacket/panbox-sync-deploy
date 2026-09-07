#!/bin/bash

#==============================================================================
# PanBox Sync 管理脚本
# 版本：2026.09.07.1
# 用途：安装、更新、重启、停止、卸载 PanBox Sync 文件同步系统
#
# 快速安装（国内用户推荐使用代理加速）：
#   # 方法 1: gh-proxy.org（推荐）
#   curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/panbox-sync.sh | sudo bash
#
#   # 方法 2: 原始地址
#   curl -fsSL https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/panbox-sync.sh | sudo bash
#
#   # 方法 3: 手动下载后执行（-O 参数强制覆盖）
#   wget -O panbox-sync.sh https://gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/panbox-sync.sh
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
INSTALL_DIR="${INSTALL_DIR:-/opt/panbox-sync}"
SCRIPT_VERSION="2026.09.07.1"
SELF_UPDATE_RESTARTED_ENV="PANBOX_SCRIPT_SELF_UPDATED"
EXTRA_COMPOSE_FILE="$INSTALL_DIR/docker-compose.extra.yml"
EXTRA_DISK_MOUNT_ROOT="/data/disks"
# 多个备用 URL，依次尝试（国内加速镜像 + 原始地址）
SCRIPT_URLS=(
    "https://gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/panbox-sync.sh"
    "https://hk.gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/panbox-sync.sh"
    "https://cdn.gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/panbox-sync.sh"
    "https://edgeone.gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/panbox-sync.sh"
    "https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/panbox-sync.sh"
)
# 多个备用 URL，依次尝试（国内加速镜像 + 原始地址）
COMPOSE_URLS=(
    "https://gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/docker-compose.yml"
    "https://hk.gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/docker-compose.yml"
    "https://cdn.gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/docker-compose.yml"
    "https://edgeone.gh-proxy.org/https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/docker-compose.yml"
    "https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/docker-compose.yml"
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

require_docker_runtime() {
    check_docker
    check_docker_compose
}

run_compose() {
    if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_error "未找到 Compose 配置：$INSTALL_DIR/docker-compose.yml"
        return 1
    fi

    local compose_files=("-f" "$INSTALL_DIR/docker-compose.yml")
    if [ -f "$EXTRA_COMPOSE_FILE" ]; then
        compose_files+=("-f" "$EXTRA_COMPOSE_FILE")
    fi

    $DOCKER_COMPOSE_CMD --project-directory "$INSTALL_DIR" "${compose_files[@]}" "$@"
}

#==============================================================================
# 脚本自更新函数
#==============================================================================

get_script_path() {
    if [ ! -f "$0" ]; then
        return 1
    fi

    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)" || return 1
    printf "%s/%s\n" "$script_dir" "$(basename "$0")"
}

extract_script_version() {
    local script_file="$1"
    grep -m1 '^SCRIPT_VERSION=' "$script_file" | sed -E 's/^SCRIPT_VERSION="?([^"[:space:]]+)"?.*/\1/'
}

self_update_script() {
    local script_path="$1"
    local new_script="$2"
    local backup_path="${script_path}.bak"
    shift 2

    if ! bash -n "$new_script"; then
        print_error "远端脚本语法检查失败，已取消自更新"
        return 1
    fi

    cp "$script_path" "$backup_path" || {
        print_error "备份当前脚本失败，无法继续自更新"
        return 1
    }

    chmod +x "$new_script"
    if ! mv "$new_script" "$script_path"; then
        print_error "替换当前脚本失败，可能没有写入权限"
        return 1
    fi

    print_success "脚本已更新，旧版本备份为：$backup_path"
    print_info "正在使用最新脚本重新启动..."
    export "$SELF_UPDATE_RESTARTED_ENV=1"
    exec "$script_path" "$@"
}

check_and_force_self_update() {
    if [ "${!SELF_UPDATE_RESTARTED_ENV:-0}" = "1" ]; then
        return 0
    fi

    local script_path
    script_path="$(get_script_path)" || {
        print_error "当前脚本不是从本地文件运行，无法执行强制自更新"
        exit 1
    }

    local tmp_file
    tmp_file="$(mktemp)"

    print_info "检查管理脚本更新..."
    if ! download_with_retry "$tmp_file" "${SCRIPT_URLS[@]}"; then
        rm -f "$tmp_file"
        print_error "脚本更新检查失败，已停止执行以避免使用过期脚本"
        exit 1
    fi

    local remote_version
    remote_version="$(extract_script_version "$tmp_file")"
    if [ -z "$remote_version" ]; then
        rm -f "$tmp_file"
        print_error "无法识别远端脚本版本，已停止执行以避免使用过期脚本"
        exit 1
    fi

    if [ "$remote_version" = "$SCRIPT_VERSION" ]; then
        rm -f "$tmp_file"
        print_success "管理脚本已是最新版本：$SCRIPT_VERSION"
        return 0
    fi

    print_warning "检测到管理脚本更新：当前 $SCRIPT_VERSION → 最新 $remote_version"
    if ! self_update_script "$script_path" "$tmp_file" "$@"; then
        rm -f "$tmp_file"
        print_error "脚本自更新失败，已停止执行以避免使用过期脚本"
        exit 1
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
        print_warning "端口 $port 已被占用，尝试下一个端口..." >&2
        port=$((port + 1))

        # 防止无限循环，最多尝试 100 个端口
        if [ $port -gt $((START_PORT + 100)) ]; then
            print_error "无法找到可用端口（已尝试 $START_PORT - $port）" >&2
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
        print_warning "OpenList 端口 $port 已被占用，尝试下一个端口..." >&2
        port=$((port + 1))

        # 防止无限循环，最多尝试 100 个端口
        if [ $port -gt $((OPENLIST_START_PORT + 100)) ]; then
            print_error "无法找到可用的 OpenList 端口（已尝试 $OPENLIST_START_PORT - $port）" >&2
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
    ip=$(curl -4 -s --connect-timeout 3 --max-time 3 https://api.ipify.org 2>/dev/null || true)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 2: ifconfig.me (强制 IPv4)
    ip=$(curl -4 -s --connect-timeout 3 --max-time 3 https://ifconfig.me 2>/dev/null || true)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 3: icanhazip.com (强制 IPv4)
    ip=$(curl -4 -s --connect-timeout 3 --max-time 3 https://icanhazip.com 2>/dev/null || true)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 4: ip.sb (强制 IPv4)
    ip=$(curl -4 -s --connect-timeout 3 --max-time 3 https://api.ip.sb/ip 2>/dev/null || true)
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
    ip=$(curl -6 -s --connect-timeout 3 --max-time 3 https://api64.ipify.org 2>/dev/null || true)
    if [ -n "$ip" ] && [[ "$ip" =~ : ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 2: icanhazip.com (强制 IPv6)
    ip=$(curl -6 -s --connect-timeout 3 --max-time 3 https://icanhazip.com 2>/dev/null || true)
    if [ -n "$ip" ] && [[ "$ip" =~ : ]]; then
        echo "$ip"
        return 0
    fi

    # 方法 3: ip.sb (强制 IPv6)
    ip=$(curl -6 -s --connect-timeout 3 --max-time 3 https://api.ip.sb/ip 2>/dev/null || true)
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
    local max_retries=3
    local retry_delay=1

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

        local attempt=1
        while [ $attempt -le $max_retries ]; do
            print_info "[$count/$total] 下载尝试 (${attempt}/${max_retries}): $source_name"
            if curl -4 -fSsL --connect-timeout 3 --max-time 8 "$url" -o "$output_file"; then
                print_success "文件下载成功"
                return 0
            fi

            if [ $attempt -lt $max_retries ]; then
                print_warning "下载超时或失败，${retry_delay} 秒后重试..."
                sleep $retry_delay
            fi

            attempt=$((attempt + 1))
        done

        print_warning "当前地址连续失败，切换下一个下载源..."
        count=$((count + 1))
    done

    print_error "所有下载地址均失败，请检查网络连接或稍后重试"
    return 1
}

download_latest_compose_config() {
    local tmp_file
    tmp_file="$(mktemp "$INSTALL_DIR/docker-compose.yml.tmp.XXXXXX")"

    if ! download_with_retry "$tmp_file" "${COMPOSE_URLS[@]}"; then
        rm -f "$tmp_file"
        return 1
    fi

    local compose_files=("-f" "$tmp_file")
    if [ -f "$EXTRA_COMPOSE_FILE" ]; then
        compose_files+=("-f" "$EXTRA_COMPOSE_FILE")
    fi

    if ! $DOCKER_COMPOSE_CMD --project-directory "$INSTALL_DIR" "${compose_files[@]}" config > /dev/null; then
        rm -f "$tmp_file"
        print_error "最新 Compose 配置校验失败，已保留当前配置和运行中的服务"
        return 1
    fi

    mv "$tmp_file" "$INSTALL_DIR/docker-compose.yml"
    print_success "Compose 配置已更新并通过校验"
}

#==============================================================================
# 数据目录与迁移函数
#==============================================================================

ensure_data_directories() {
    print_info "创建数据目录..."
    mkdir -p "$INSTALL_DIR/data/openlist" "$INSTALL_DIR/data/smartdns/log"

    if [ ! -f "$INSTALL_DIR/data/smartdns/smartdns.conf" ]; then
        cat > "$INSTALL_DIR/data/smartdns/smartdns.conf" <<'EOF'
bind :53
bind-tcp :53

# 日志别长期 debug，太吵也影响性能
log-level info
log-console yes

# 关闭 IPv6 查询，适合你现在这个没有 IPv6 的 Docker/VPS 环境
force-AAAA-SOA yes
dualstack-ip-selection no

# 缓存，网盘下载很吃这个
cache-size 10000
cache-persist yes
cache-file /etc/smartdns/smartdns.cache
prefetch-domain yes
serve-expired yes

# TTL 稳一点，避免 CDN 来回漂
rr-ttl-min 300
rr-ttl-max 3600

# 默认上游
server 223.6.6.6
server 223.5.5.5
server 119.29.29.29

# 百度组
server 180.76.76.76 -group baidu -exclude-default-group
server 180.184.1.1  -group baidu -exclude-default-group
server 180.184.2.2  -group baidu -exclude-default-group

nameserver /baidu.com/baidu
nameserver /bdstatic.com/baidu
nameserver /baidupcs.com/baidu
nameserver /bcebos.com/baidu
nameserver /d.pcs.baidu.com/baidu
nameserver /pan.baidu.com/baidu

# 百度下载
domain-rules /baidupcs.com/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip
domain-rules /bcebos.com/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip
domain-rules /d.pcs.baidu.com/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip
domain-rules /pan.baidu.com/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip

# 夸克 / UC
domain-rules /pds.quark.cn/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip
domain-rules /drive.quark.cn/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip
domain-rules /pan.quark.cn/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip
domain-rules /uc123.com/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip
domain-rules /drive.uc.cn/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip

# 阿里云盘 / OSS/CDN
domain-rules /alipan.com/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip
domain-rules /aliyuncs.com/ -speed-check-mode tcp:80,tcp:443 -response-mode fastest-ip
EOF
    elif grep -qx 'bind \[::\]:53' "$INSTALL_DIR/data/smartdns/smartdns.conf"; then
        print_warning "检测到旧版默认 SmartDNS IPv6 监听配置，自动移除以提升兼容性"
        sed -i.bak '/^bind \[::\]:53$/d' "$INSTALL_DIR/data/smartdns/smartdns.conf"
    fi

    chown -R 10001:10001 "$INSTALL_DIR/data"
    print_success "数据目录创建完成"
}

migrate_openlist_data_dir() {
    local legacy_dir="$INSTALL_DIR/openlist-data"
    local target_dir="$INSTALL_DIR/data/openlist"

    if [ ! -d "$legacy_dir" ]; then
        print_info "未检测到旧版 OpenList 数据目录，跳过迁移"
        return 0
    fi

    if [ -z "$(find "$legacy_dir" -mindepth 1 -print -quit 2>/dev/null)" ]; then
        print_info "旧版 OpenList 数据目录为空，跳过迁移"
        return 0
    fi

    mkdir -p "$target_dir"

    print_info "迁移 OpenList 数据目录：$legacy_dir -> $target_dir"
    cp -a "$legacy_dir"/. "$target_dir"/

    local missing_count=0
    while IFS= read -r relative_path; do
        [ -z "$relative_path" ] && continue
        if [ ! -e "$target_dir/$relative_path" ]; then
            print_error "迁移校验失败，缺少文件：$relative_path"
            missing_count=$((missing_count + 1))
            break
        fi
    done < <(cd "$legacy_dir" && find . -mindepth 1 | sort)

    if [ "$missing_count" -ne 0 ]; then
        print_error "OpenList 数据迁移失败，请检查磁盘空间和目录权限"
        exit 1
    fi

    chown -R 10001:10001 "$INSTALL_DIR/data"
    print_success "OpenList 数据迁移完成，已确认复制成功"
    print_warning "旧目录已保留为兼容备份：$legacy_dir"
}

stop_compose_services() {
    print_info "停止 Compose 服务..."
    if run_compose down; then
        print_success "Compose 服务已停止"
    else
        print_error "Compose 服务停止失败"
        exit 1
    fi
}

#==============================================================================
# 额外空间挂载函数
#==============================================================================

escape_yaml_double_quoted() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf "%s" "$value"
}

validate_extra_disk_base_dir() {
    local base_dir="$1"

    if [ -z "$base_dir" ]; then
        print_error "宿主机路径不能为空"
        return 1
    fi

    if [[ "$base_dir" != /* ]]; then
        print_error "请输入绝对路径，例如：/data"
        return 1
    fi

    if [[ "$base_dir" == *$'\n'* || "$base_dir" == *:* || "$base_dir" == *\"* || "$base_dir" == *\\* ]]; then
        print_error "路径不能包含换行、冒号、双引号或反斜杠"
        return 1
    fi

    case "$base_dir" in
        /|/bin|/boot|/dev|/etc|/lib|/lib64|/proc|/root|/run|/sbin|/sys|/usr|/var)
            print_error "该路径过于敏感，请选择专用数据目录，例如：/data"
            return 1
            ;;
    esac

    return 0
}

resolve_directory_path() {
    local dir="$1"
    local parent_dir
    local base_name

    parent_dir="$(dirname "$dir")"
    base_name="$(basename "$dir")"

    if [ ! -d "$parent_dir" ]; then
        print_error "父目录不存在：$parent_dir"
        return 1
    fi

    local resolved_parent
    resolved_parent="$(cd "$parent_dir" && pwd -P)" || return 1
    printf "%s/%s\n" "$resolved_parent" "$base_name"
}

collect_extra_disk_hosts() {
    if [ ! -f "$EXTRA_COMPOSE_FILE" ]; then
        return 0
    fi

    grep -E '^[[:space:]]*-[[:space:]]*"/.+:/data/disks/disk-[0-9]+"[[:space:]]*$' "$EXTRA_COMPOSE_FILE" \
        | sed -E 's/^[[:space:]]*-[[:space:]]*"(.*):\/data\/disks\/disk-[0-9]+"[[:space:]]*$/\1/' \
        || true
}

write_extra_compose_file() {
    local hosts=("$@")
    local tmp_file
    tmp_file="$(mktemp)"

    {
        echo "version: '3.8'"
        echo ""
        echo "services:"
        echo "  panbox-sync:"
        echo "    volumes:"

        local index=1
        local host_path
        for host_path in "${hosts[@]}"; do
            [ -z "$host_path" ] && continue
            echo "      - \"$(escape_yaml_double_quoted "$host_path"):${EXTRA_DISK_MOUNT_ROOT}/disk-${index}\""
            index=$((index + 1))
        done
    } > "$tmp_file"

    mv "$tmp_file" "$EXTRA_COMPOSE_FILE"
}

add_extra_space() {
    print_header "增加空间"
    require_docker_runtime

    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_error "未检测到已安装的 PanBox Sync，请先执行安装"
        exit 1
    fi

    echo "请输入宿主机数据路径，例如：/data"
    read -r -p "宿主机路径: " base_dir < /dev/tty

    if ! validate_extra_disk_base_dir "$base_dir"; then
        return 1
    fi

    local disk_dir="$base_dir/panbox-sync-disk"
    local resolved_disk_dir

    mkdir -p "$disk_dir" || {
        print_error "创建目录失败：$disk_dir"
        return 1
    }

    resolved_disk_dir="$(resolve_directory_path "$disk_dir")" || return 1

    if [ ! -w "$resolved_disk_dir" ]; then
        print_error "目录不可写：$resolved_disk_dir"
        return 1
    fi

    chown -R 10001:10001 "$resolved_disk_dir" || {
        print_error "设置目录权限失败：$resolved_disk_dir"
        return 1
    }

    local existing_hosts=()
    local existing_host
    while IFS= read -r existing_host; do
        [ -z "$existing_host" ] && continue
        existing_hosts+=("$existing_host")
    done < <(collect_extra_disk_hosts)

    for existing_host in "${existing_hosts[@]}"; do
        if [ "$existing_host" = "$resolved_disk_dir" ]; then
            print_warning "该目录已添加过：$resolved_disk_dir"
            print_info "将使用现有额外挂载配置重建服务"
            if run_compose up -d; then
                print_success "服务已重建，额外挂载保持不变"
                return 0
            fi
            print_error "服务重建失败"
            return 1
        fi
    done

    existing_hosts+=("$resolved_disk_dir")
    write_extra_compose_file "${existing_hosts[@]}"

    print_success "额外空间已写入：$EXTRA_COMPOSE_FILE"
    print_info "宿主机目录：$resolved_disk_dir"
    print_info "容器内路径：${EXTRA_DISK_MOUNT_ROOT}/disk-${#existing_hosts[@]}"
    print_info "正在重建服务以应用挂载..."

    if run_compose up -d; then
        print_success "额外空间已生效"
    else
        print_error "服务重建失败，请检查 Compose 配置"
        return 1
    fi
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
# sysctl 网络优化函数
#==============================================================================

set_sysctl_value() {
    local key="$1"
    local value="$2"
    local config_file="/etc/sysctl.conf"

    if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$config_file"; then
        sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "$config_file"
    else
        printf '\n%s=%s\n' "$key" "$value" >> "$config_file"
    fi
}

apply_network_sysctl_optimizations() {
    print_info "应用网络优化配置..."

    set_sysctl_value "net.core.default_qdisc" "fq"
    set_sysctl_value "net.ipv4.tcp_congestion_control" "bbr"
    set_sysctl_value "net.ipv4.tcp_fastopen" "3"

    if sysctl -p; then
        print_success "网络优化配置已应用"
    else
        print_warning "sysctl -p 执行失败，请手动检查 /etc/sysctl.conf 配置"
    fi
}

prompt_network_sysctl_optimizations() {
    echo ""
    print_info "推荐在初次安装时应用网络优化（BBR / FQ / TCP Fast Open），可提升大文件传输体验"
    print_warning "该操作会修改宿主机 /etc/sysctl.conf 并立即应用系统网络参数"
    read -p "是否应用推荐网络优化？[Y/n]: " confirm < /dev/tty

    if [[ -n "$confirm" && ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已跳过网络优化"
        return 0
    fi

    apply_network_sysctl_optimizations
}

#==============================================================================
# 安装函数
#==============================================================================

install_panbox() {
    print_header "安装 PanBox Sync"
    require_docker_runtime

    # 检查是否已安装
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_warning "检测到已安装 PanBox Sync"
        read -p "是否切换为更新流程？[Y/n]: " confirm < /dev/tty
        if [[ -n "$confirm" && ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "取消安装"
            return 0
        fi

        print_info "已切换为更新流程..."
        update_panbox
        return 0
    fi

    # 创建目录
    ensure_data_directories

    # 检测 Docker GID
    detect_docker_gid

    # 推荐应用宿主机网络优化
    prompt_network_sysctl_optimizations

    # 查找可用端口
    print_info "检测可用端口..."
    AVAILABLE_PORT=$(find_available_port)
    AVAILABLE_OPENLIST_PORT=$(find_available_openlist_port)
    print_success "端口检测完成"

    # 创建 .env 文件
    create_env_file

    # 下载并校验 docker-compose.yml（自动尝试多个备用地址）
    print_info "下载配置文件..."
    if ! download_latest_compose_config; then
        exit 1
    fi

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
    if run_compose up -d; then
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
    require_docker_runtime

    # 检查是否已安装
    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_error "未检测到已安装的 PanBox Sync，请先执行安装"
        exit 1
    fi

    cd "$INSTALL_DIR"

    # 先获取并校验新配置，失败时不影响当前运行中的服务
    detect_docker_gid
    print_info "下载最新配置文件..."
    if ! download_latest_compose_config; then
        exit 1
    fi

    # 删除旧容器后执行数据迁移；绑定挂载的数据目录和业务文件保持不变
    stop_compose_services
    ensure_data_directories
    migrate_openlist_data_dir
    create_env_file

    # 拉取最新镜像
    print_info "拉取最新镜像..."
    if docker pull "$DOCKER_IMAGE"; then
        print_success "镜像拉取成功"
    else
        print_error "镜像拉取失败"
        exit 1
    fi

    # 使用新 Compose 配置启动服务
    print_info "启动服务..."
    if run_compose up -d --force-recreate; then
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
    require_docker_runtime

    # 检查是否已安装
    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_error "未检测到已安装的 PanBox Sync，请先执行安装"
        exit 1
    fi

    cd "$INSTALL_DIR"

    print_info "重启服务..."
    if run_compose restart; then
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
    require_docker_runtime

    # 检查是否已安装
    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_error "未检测到已安装的 PanBox Sync"
        exit 1
    fi

    cd "$INSTALL_DIR"

    print_info "停止服务..."
    if run_compose down; then
        print_success "服务已停止"
    else
        print_error "服务停止失败"
        exit 1
    fi
}

uninstall_panbox() {
    print_header "卸载 PanBox Sync"

    if [ ! -d "$INSTALL_DIR" ]; then
        print_warning "未检测到安装目录：$INSTALL_DIR"
        return 0
    fi

    print_warning "此操作将完全卸载 PanBox Sync"
    print_warning "将删除容器、网络、镜像，以及 $INSTALL_DIR 下的所有配置和数据"
    read -p "确认继续卸载？[y/N]: " confirm < /dev/tty
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消卸载"
        return 0
    fi

    local compose_cmd=""
    if command -v docker-compose &> /dev/null; then
        compose_cmd="docker-compose"
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    fi

    if [ -n "$compose_cmd" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        cd "$INSTALL_DIR"
        DOCKER_COMPOSE_CMD="$compose_cmd"
        print_info "停止并删除 Compose 资源..."
        if run_compose down --remove-orphans; then
            print_success "Compose 资源已删除"
        else
            print_warning "Compose 资源删除失败，继续清理本地文件"
        fi
    else
        print_warning "未检测到可用的 Compose 环境，跳过 Compose 资源清理"
    fi

    if command -v docker &> /dev/null && docker image inspect "$DOCKER_IMAGE" > /dev/null 2>&1; then
        print_info "删除 Docker 镜像..."
        if docker image rm -f "$DOCKER_IMAGE" > /dev/null 2>&1; then
            print_success "Docker 镜像已删除"
        else
            print_warning "Docker 镜像删除失败，可能仍被其他容器占用"
        fi
    fi

    print_info "删除本地目录..."
    rm -rf "$INSTALL_DIR"
    print_success "PanBox Sync 已完全卸载"
}

#==============================================================================
# 显示访问信息
#==============================================================================

show_access_info() {
    local backend_port=$1

    PUBLIC_IPV4=$(get_public_ipv4)
    PUBLIC_IPV6=$(get_public_ipv6)
    LOCAL_IPV4=$(get_local_ipv4)

    echo ""
    print_success "✅ 应用已成功启动！"
    print_info "📍 最终访问路径"

    if [ "$LOCAL_IPV4" != "无法获取" ]; then
        echo "   内网地址：http://$LOCAL_IPV4:$backend_port"
    else
        echo "   内网地址：未检测到内网 IP"
    fi

    if [ "$PUBLIC_IPV4" != "无法获取" ]; then
        echo "   外网地址：http://$PUBLIC_IPV4:$backend_port"
    elif [ "$PUBLIC_IPV6" != "无法获取" ]; then
        echo "   外网地址：http://[$PUBLIC_IPV6]:$backend_port"
    else
        echo "   外网地址：未检测到公网 IP"
    fi

    echo ""
    print_warning "💾 请保存以上访问地址"
    print_warning "首次使用：请在 PanBox Sync 界面注册账号并激活后登录"
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
EOF
    echo "            Version ${SCRIPT_VERSION}"
    echo ""
    echo -e "${BLUE}请选择操作：${NC}"
    echo "  1) 安装 PanBox Sync"
    echo "  2) 更新 PanBox Sync"
    echo "  3) 重启 PanBox Sync"
    echo "  4) 停止 PanBox Sync"
    echo "  5) 增加空间"
    echo "  6) 卸载 PanBox Sync（删除本地全部数据）"
    echo "  7) 应用网络优化（BBR / FQ / TCP Fast Open）"
    echo "  0) 退出"
    echo ""
}

#==============================================================================
# 主流程
#==============================================================================

main() {
    # 检查环境
    check_root
    check_and_force_self_update "$@"

    while true; do
        show_menu
        read -p "请输入选项 [0-7]: " choice < /dev/tty

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
            5)
                add_extra_space
                read -p "按 Enter 键返回菜单..." < /dev/tty
                ;;
            6)
                uninstall_panbox
                read -p "按 Enter 键返回菜单..." < /dev/tty
                ;;
            7)
                apply_network_sysctl_optimizations
                read -p "按 Enter 键返回菜单..." < /dev/tty
                ;;
            0)
                print_info "退出脚本"
                exit 0
                ;;
            *)
                print_error "无效选项，请输入 0-7"
                sleep 2
                ;;
        esac
    done
}

# 运行主函数（测试可只加载函数，不触发交互菜单）
if [ "${PANBOX_SYNC_TEST_MODE:-0}" != "1" ]; then
    main "$@"
fi
