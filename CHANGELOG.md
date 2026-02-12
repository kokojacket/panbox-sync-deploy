# Changelog

## [Unreleased] - 2026-02-13

### Changed
- `panbox-sync.sh`：下载配置文件新增重试机制（每个源最多重试 3 次），并采用 `--connect-timeout 3 --max-time 8`，失败后自动切换下一个下载源。
- `panbox-sync.sh`：公网/IPv6 IP 探测请求增加 `--max-time 3` 与 `|| true`，避免在 `set -e` 下因网络探测失败导致脚本提前退出。
- `panbox-sync.sh`：部署完成输出简化为“应用启动状态 + 最终访问路径（内网/外网）”，并保留首次使用提醒。
