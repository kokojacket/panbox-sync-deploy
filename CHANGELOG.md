# Changelog

## [Unreleased] - 2026-02-13

### Changed
- `docker-compose.yml`：容器数据根挂载统一改为宿主机 `/data -> /data`，并将 `PANBOX_SYNC_DATA_DIR` / `INTERNAL_OPENLIST_DATA` 同步切换到 `/data` / `/data/openlist`，避免部署后继续写回旧目录。
- `panbox-sync.sh`：安装与更新流程新增旧版数据布局自动迁移，启动新版 compose 前会先检测 `/opt/panbox-sync/data` 与 `/opt/panbox-sync/openlist-data`，停服务后迁移到宿主机 `/data`，并保留迁移标记与回滚备份。
- `panbox-sync.sh`：统一数据目录准备、权限修复与 compose 下载流程，确保新装与升级都走同一套 `/data` 根目录逻辑。
- `panbox-sync.sh`：下载配置文件新增重试机制（每个源最多重试 3 次），并采用 `--connect-timeout 3 --max-time 8`，失败后自动切换下一个下载源。
- `panbox-sync.sh`：公网/IPv6 IP 探测请求增加 `--max-time 3` 与 `|| true`，避免在 `set -e` 下因网络探测失败导致脚本提前退出。
- `panbox-sync.sh`：部署完成输出简化为“应用启动状态 + 最终访问路径（内网/外网）”，并保留首次使用提醒。
