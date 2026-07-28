# Changelog

## [Unreleased] - 2026-03-23

### Changed
- `docker-compose.yml`：为 PanBox Sync 与 SmartDNS 容器启用 Docker 原生 `json-file` 轮转，单文件 10 MiB、保留 3 份，避免容器日志无限增长。
- `panbox-sync.sh`：更新时先下载并校验最新 Compose 配置，再停止旧服务；随后强制重建容器，确保日志驱动配置实际写入新容器并由 Docker 回收旧容器日志。
- `panbox-sync.sh`：新增“增加空间”菜单项，可输入宿主机路径并自动创建 `<路径>/panbox-sync-disk`，挂载到容器内 `/data/disks/disk-N`。
- `panbox-sync.sh`：新增本地 `docker-compose.extra.yml` override 机制，并统一 Compose 调用入口，确保安装、更新、重启、停止、卸载与额外空间重建都会保留本地挂载。
- `docker-compose.yml`：显式声明 `PANBOX_SYNC_EXTRA_DOWNLOAD_ROOT=/data/disks`，与脚本新增空间的容器内受控挂载路径保持一致。
- `panbox-sync.sh`：更新首次生成的 SmartDNS 默认配置，启用控制台日志、TCP 53 监听、持久缓存、IPv6 查询抑制与网盘域名测速规则。
- `docker-compose.yml`：SmartDNS 服务改用镜像默认启动入口，将配置文件只读挂载到 `/etc/smartdns/smartdns.conf`，并声明容器内 `53/udp` 与 `53/tcp`。
- `docker-compose.yml`：挂载 `data/smartdns/log` 到 SmartDNS 容器日志目录，便于在宿主机查看 `smartdns.log`。
- `panbox-sync.sh`：SmartDNS 默认配置改为仅监听 IPv4，并为旧版自动生成配置移除 IPv6 通配监听，降低容器启动兼容性问题。
- `panbox-sync.sh`：创建数据目录时自动生成缺失的 `data/smartdns/smartdns.conf`，避免 SmartDNS 因配置文件不存在启动失败。
- `docker-compose.yml`：修复 SmartDNS 容器启动命令，显式执行 `smartdns`，避免 Docker 将 `-f` 误识别为可执行文件导致更新失败。
- `panbox-sync.sh`：新增启动时强制自更新流程，从远端下载最新脚本、校验语法、备份旧脚本并自动重启；检查或更新失败时停止执行，避免继续使用过期脚本。
- `docker-compose.yml`：新增 `smartdns` 服务与固定桥接网络，PanBox Sync 容器默认使用 SmartDNS 解析并挂载统一数据目录。
- `docker-compose.yml`：补充 `SMARTDNS_CONTAINER_NAME` 环境变量与 Docker socket 说明，支持后端管理 SmartDNS 容器配置。
- `panbox-sync.sh`：新增“应用网络优化（BBR / FQ / TCP Fast Open）”菜单项，可写入并应用常用 sysctl 网络参数。
- `panbox-sync.sh`：初次安装流程增加推荐网络优化确认，默认应用 BBR / FQ / TCP Fast Open，用户可输入 `n` 跳过。
- `panbox-sync.sh`：新增“卸载 PanBox Sync”菜单项，支持二次确认后停止并删除 Compose 资源、清理镜像，并移除 `/opt/panbox-sync` 下全部本地配置与数据目录。
- `panbox-sync.sh`：Docker / Compose 运行时检查改为在安装、更新、重启、停止时按需执行，避免仅做卸载时被全局环境检查提前拦截。
- `panbox-sync.sh`：主菜单同步扩展为 `0-6` 选项范围，并补充卸载与网络优化入口提示。

## [Unreleased] - 2026-02-13
