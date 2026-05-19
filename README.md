# aranapi

目标是 **构建 New API 并上线**：本仓库以文档与模板为主（systemd / 反代 / 可选 Docker），**不负责 fork 上游业务代码**。上游项目：<https://github.com/QuantumNous/new-api>；文档：<https://docs.newapi.pro/en/docs/installation>。

## 推荐路径：源码构建 → systemd → HTTPS

完整步骤见 **`docs/production.md`**（含 CGO/SQLite、前端构建、`make build-all-frontends`、发布清单）。

常用模板：

- **构建脚本**：`scripts/build-new-api.sh`（需本地已 clone 上游并设置 `NEW_API_SRC`）  
- **systemd**：`deploy/systemd/new-api.service.example`  
- **环境变量示例**：`deploy/env.new-api.systemd.example` → 复制为 `/etc/new-api.env`（`chmod 600`）  
- **裸机 Caddy**：`deploy/Caddyfile.baremetal`（`DOMAIN=api.example.com`，反代到 `127.0.0.1:3000`）

首次登录控制台后请 **立刻修改管理员默认密码**，再配置上游渠道与令牌。

## 一键发布（GitHub Actions）

工作流：**`.github/workflows/release-new-api.yml`**（构建 `linux/amd64` + `linux/arm64`，`CGO_ENABLED=0`，打包 `SHA256SUMS.txt`）。

1. 编辑 **`release/upstream-ref.txt`**：`latest` 跟上游 Latest Release；生产建议钉死为上游 **tag**。说明见 **`release/README.md`**。  
2. 在本仓库创建并推送 **`v*` 标签**：
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   → GitHub 自动生成 Release，并附上 tarball。  
3. 也可在 Actions 里 **手动 Run workflow**：可选覆盖 `upstream_ref`；仅出构件时不勾选 **publish_release**；要直接在远端创建 Release 则勾选并填写 **release_tag**。

详情：**`docs/production.md`** 第 9 节。

## 附录：Docker 编排（可选）

若你希望用容器交付而不是本机构建，可使用根目录下的 Compose 文件（SQLite / Postgres / Caddy / Cloudflare Tunnel）。详见各文件内注释；冒烟脚本：`scripts/smoke.sh`。

## 生产检查清单（精简）

- 固定上游 **release/tag** 构建；保存构件哈希与构建命令备查。  
- 配置 `SESSION_SECRET`；若启用 Redis，配置 `CRYPTO_SECRET`（见上游文档）。  
- 上游默认监听 **`0.0.0.0:PORT`**，应用端口勿裸奔公网——用防火墙或 Tunnel，仅让 80/443 对外。  
- 定期备份数据库（SQLite 文件或 Postgres/MySQL）。  
- 遵守 **AGPLv3** 义务及模型服务商条款与当地法律法规。
