# Deploy 发布仓库协作指南

`deploy/` 是独立 Git 仓库 `kokojacket/panbox-sync-deploy` 的本地副本，不属于主仓库提交历史；修改后需要在 `deploy/` 内单独提交并推送。

## 必须同步更新

- 修改 `panbox-sync.sh` 时必须同步更新脚本内部版本号：`SCRIPT_VERSION="YYYY.MM.DD.N"`。
- 修改部署行为、安装/更新流程、Compose 配置或默认数据文件时必须同步更新 `CHANGELOG.md` 的 `[Unreleased]` 条目。
- 修复线上安装/更新问题时，优先确认 `panbox-sync.sh` 下载源和 `docker-compose.yml` 是否都需要变更；更新流程每次会重新下载 Compose 配置。

## SmartDNS 注意事项

- `docker-compose.yml` 中 `smartdns` 服务必须显式执行 `smartdns`，不要让 `command` 以 `-f` 等参数开头。
- SmartDNS 配置路径是容器内 `/data/smartdns/smartdns.conf`，对应宿主机 `/opt/panbox-sync/data/smartdns/smartdns.conf`。
- SmartDNS 日志目录必须挂载到宿主机 `data/smartdns/log`，方便排查 `/var/log/smartdns/smartdns.log` 中的启动失败原因。
- `panbox-sync.sh` 的数据目录初始化必须创建 `data/smartdns/log`，并仅在 `smartdns.conf` 缺失时生成默认配置；不要覆盖用户已有配置。

## 验证要求

- 修改 `panbox-sync.sh` 后至少运行：`bash -n deploy/panbox-sync.sh`。
- 修改 Compose 后优先运行：`docker compose -f deploy/docker-compose.yml config`；如果本机没有 Docker，需在回复和提交信息中注明未执行。
- 提交前使用 `git -C deploy diff` 和 `git -C deploy status --short --branch` 确认只包含预期文件。

## 提交与推送

- 在 `deploy/` 仓库内提交：`git -C deploy ...`。
- 提交信息使用中文，说明修复原因和影响范围。
- 用户明确要求推送时，推送到 `origin main`。
