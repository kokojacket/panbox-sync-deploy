# Changelog

## [Unreleased] - 2026-02-13

### Changed
- `docker-compose.yml`：继续沿用方案A路径策略，宿主机通过安装目录下的 `./data -> /data` 挂载统一承载 PanBox 与内置 OpenList 数据，对应实际部署路径 `/opt/panbox-sync/data`。
- `panbox-sync.sh`：安装与更新流程补充针对“已被错误迁移到宿主机 /data”的兼容回迁逻辑；升级时会停服务后将 `/data` 重新合并回方案A目录，并为目标目录保留备份与新版迁移标记。
- `panbox-sync.sh`：保留对更早期 `/opt/panbox-sync/openlist-data` 目录的兼容迁移，确保旧 OpenList 数据会继续汇入 `./data/openlist`。
- `panbox-sync.sh`：下载配置文件新增重试机制（每个源最多重试 3 次），并采用 `--connect-timeout 3 --max-time 8`，失败后自动切换下一个下载源。
- `panbox-sync.sh`：公网/IPv6 IP 探测请求增加 `--max-time 3` 与 `|| true`，避免在 `set -e` 下因网络探测失败导致脚本提前退出。
- `panbox-sync.sh`：部署完成输出简化为“应用启动状态 + 最终访问路径（内网/外网）”，并保留首次使用提醒。
