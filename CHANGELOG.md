# Changelog

## [Unreleased] - 2026-03-23

### Changed
- `panbox-sync.sh`：新增“卸载 PanBox Sync”菜单项，支持二次确认后停止并删除 Compose 资源、清理镜像，并移除 `/opt/panbox-sync` 下全部本地配置与数据目录。
- `panbox-sync.sh`：Docker / Compose 运行时检查改为在安装、更新、重启、停止时按需执行，避免仅做卸载时被全局环境检查提前拦截。
- `panbox-sync.sh`：主菜单同步扩展为 `0-5` 选项范围，并补充卸载入口提示。

## [Unreleased] - 2026-02-13
