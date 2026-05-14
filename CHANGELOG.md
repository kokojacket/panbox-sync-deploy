# Changelog

## [Unreleased] - 2026-03-23

### Changed
- `docker-compose.yml`：SmartDNS 服务改用镜像默认启动入口，将配置文件只读挂载到 `/etc/smartdns/smartdns.conf`，并声明容器内 `53/udp` 与 `53/tcp`。
- `docker-compose.yml`：挂载 `data/smartdns/log` 到 SmartDNS 容器日志目录，便于在宿主机查看 `smartdns.log`。
- `panbox-sync.sh`：SmartDNS 默认配置改为仅监听 IPv4，并为旧版自动生成配置移除 IPv6 通配监听，降低容器启动兼容性问题。
- `panbox-sync.sh`：创建数据目录时自动生成缺失的 `data/smartdns/smartdns.conf`，避免 SmartDNS 因配置文件不存在启动失败。
- `docker-compose.yml`：修复 SmartDNS 容器启动命令，显式执行 `smartdns`，避免 Docker 将 `-f` 误识别为可执行文件导致更新失败。
- `panbox-sync.sh`：新增启动时强制自更新流程，从远端下载最新脚本、校验语法、备份旧脚本并自动重启；检查或更新失败时停止执行，避免继续使用过期脚本。
- `docker-compose.yml`：新增 `smartdns` 服务与固定桥接网络，PanBox Sync 容器默认使用 SmartDNS 解析并挂载统一数据目录。
- `docker-compose.yml`：补充 `SMARTDNS_CONTAINER_NAME` 环境变量与 Docker socket 说明，支持后端管理 SmartDNS 容器配置。
- `panbox-sync.sh`：新增“应用网络优化（BBR / FQ / TCP Fast Open）”菜单项，可写入并应用常用 sysctl 网络参数。
- `panbox-sync.sh`：新增“卸载 PanBox Sync”菜单项，支持二次确认后停止并删除 Compose 资源、清理镜像，并移除 `/opt/panbox-sync` 下全部本地配置与数据目录。
- `panbox-sync.sh`：Docker / Compose 运行时检查改为在安装、更新、重启、停止时按需执行，避免仅做卸载时被全局环境检查提前拦截。
- `panbox-sync.sh`：主菜单同步扩展为 `0-6` 选项范围，并补充卸载与网络优化入口提示。

## [Unreleased] - 2026-02-13
