# PanBox Sync 一键安装脚本（Windows PowerShell）

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "   PanBox Sync 一键安装脚本" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# 检查 Docker
try {
    docker --version | Out-Null
} catch {
    Write-Host "错误: 未检测到 Docker，请先安装 Docker Desktop" -ForegroundColor Red
    Write-Host "下载地址: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# 检查 Docker Compose
try {
    docker-compose --version | Out-Null
} catch {
    try {
        docker compose version | Out-Null
    } catch {
        Write-Host "错误: 未检测到 Docker Compose" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✓ Docker 环境检查通过" -ForegroundColor Green
Write-Host ""

# 创建安装目录
$installDir = if ($args[0]) { $args[0] } else { ".\panbox-sync" }
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Set-Location $installDir

Write-Host "安装目录: $(Get-Location)" -ForegroundColor Blue
Write-Host ""

# 下载配置文件
Write-Host "正在下载配置文件..." -ForegroundColor Blue
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/docker-compose.yml" -OutFile "docker-compose.yml"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kokojacket/panbox-sync-deploy/main/.env.example" -OutFile ".env.example"

# 创建 .env 文件
if (-not (Test-Path ".env")) {
    Write-Host "请配置环境变量..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"

    # 生成随机密钥
    $secretKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | ForEach-Object {[char]$_})
    (Get-Content ".env") -replace "your_secret_key_here_please_change_me", $secretKey | Set-Content ".env"

    Write-Host "请编辑 .env 文件，配置以下必需项：" -ForegroundColor Yellow
    Write-Host "  - DB_PASSWORD: 数据库密码"
    Write-Host "  - OPENLIST_URL: OpenList 服务器地址"
    Write-Host ""
    Write-Host "按回车键打开 .env 文件..." -ForegroundColor Yellow
    Read-Host
    notepad ".env"
}

Write-Host "✓ 配置文件准备完成" -ForegroundColor Green
Write-Host ""

# 拉取镜像
Write-Host "正在拉取 Docker 镜像..." -ForegroundColor Blue
docker-compose pull

# 启动服务
Write-Host "正在启动服务..." -ForegroundColor Blue
docker-compose up -d

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "访问地址: http://localhost:8000" -ForegroundColor Blue
Write-Host ""
Write-Host "常用命令:"
Write-Host "  查看日志: docker-compose logs -f"
Write-Host "  停止服务: docker-compose stop"
Write-Host "  启动服务: docker-compose start"
Write-Host "  重启服务: docker-compose restart"
Write-Host "  卸载服务: docker-compose down -v"
Write-Host ""
