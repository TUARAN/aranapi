# 生产上线：源码构建 New API（非 Docker）

本文面向「构建产物 → 放到 VPS/systemd → 反代/Tunnel 上线」。上游项目：<https://github.com/QuantumNous/new-api>，文档：<https://docs.newapi.pro/en/docs/installation/deployment-methods/local-development>。

## 1. 版本与合规

- **固定版本**：用上游 **tag / release** 构建，避免 `main` 漂移（便于回滚与审计）。  
- **许可证**：上游为 **AGPLv3**（另有附加条款）；发布前请做法务评估。  
- **条款**：遵守模型服务商 ToS 与当地监管要求。

## 2. 构建环境要求

与上游「Local Development」一致（版本号随上游升级可能变化，以官方文档为准）：

- **Go**：与上游 `go.mod` 对齐（当前仓库 CI 使用 **1.25.x**）  
- **Bun**：用于构建前端（上游 `makefile` 默认走 `web/default` 与 `web/classic`）  
- （可选）**MySQL / PostgreSQL / Redis**：生产建议外置数据库与 Redis；SQLite 仅适合极小流量或过渡。

### SQLite 与 CGO

上游默认使用 **`github.com/glebarez/sqlite`**（基于 **modernc.org/sqlite**，纯 Go）。在该默认组合下，**`CGO_ENABLED=0` 也可构建**，本仓库的 **GitHub Actions 一键发布**即采用这种方式交叉编译 `linux/amd64` 与 `linux/arm64`。

若你改用依赖 **CGO** 的 SQLite 驱动或静态链接策略变化，则需要按目标平台单独验证（必要时在对应架构的机器本机编译）。

## 3. 构建步骤（手动）

```bash
git clone https://github.com/QuantumNous/new-api.git
cd new-api
git checkout <pinned-tag>

cp .env.example .env
# 按生产填写 PORT / SQL_DSN / SESSION_SECRET / REDIS_CONN_STRING / CRYPTO_SECRET 等
# 完整列表：https://docs.newapi.pro/en/docs/installation/config-maintenance/environment-variables

go mod download

# 前端（与上游 makefile 一致）
make build-all-frontends

# 后端二进制（默认 glebarez/sqlite 可用纯 Go 构建）
CGO_ENABLED=0 go build -o new-api .

# 运行（前台验证）
./new-api --log-dir /var/log/new-api
```

验证：本机 `curl -sfS http://127.0.0.1:3000/api/status` 返回 JSON 且带 `"success":true`。

### 监听地址与安全说明

上游默认使用 Gin 的 `server.Run(":" + PORT)`，等价于监听 **`0.0.0.0`**。上线时请用 **防火墙**（例如仅允许本机回环访问 `PORT`，对外开放 80/443 给反代）或 **仅内网 + Tunnel**，不要直接把应用端口暴露公网又无鉴权加固。

## 4. 一键脚本（可选）

仓库提供 `scripts/build-new-api.sh`：在已 clone 的上游目录执行 `make build-all-frontends` 与 `go build`。

```bash
export NEW_API_SRC=/path/to/new-api
./scripts/build-new-api.sh
```

可通过环境变量覆盖：

- `CGO_ENABLED`（默认 `0`，与 CI 一致）  
- `GOOS` / `GOARCH`（交叉编译时自行承担 SQLite/CGO 风险）

## 5. 上线目录与权限（示例）

示例布局（可按习惯调整）：

- 二进制：`/opt/new-api/new-api`  
- 数据（SQLite 时）：`/var/lib/new-api/`（注意备份）  
- 日志：`/var/log/new-api/`  
- 环境：`/etc/new-api.env`（**chmod 600**，勿提交仓库）

创建低权限用户：

```bash
sudo useradd --system --home /opt/new-api --shell /usr/sbin/nologin newapi || true
sudo mkdir -p /opt/new-api /var/lib/new-api /var/log/new-api
sudo chown -R newapi:newapi /opt/new-api /var/lib/new-api /var/log/new-api
```

将构建产物 `new-api` 拷贝到 `/opt/new-api/`，并把 `.env` 内容迁移到 `/etc/new-api.env`（或使用上游支持的配置文件路径——以官方文档为准）。

## 6. systemd

参考本仓库 `deploy/systemd/new-api.service.example`，复制为 `/etc/systemd/system/new-api.service` 后：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now new-api
sudo systemctl status new-api --no-pager
```

## 7. HTTPS 反代（Caddy / Nginx）

**推荐**：New API 仅监听 `127.0.0.1:3000`，由本机 Caddy/Nginx 终止 TLS。

- 裸机 Caddy 示例：`deploy/Caddyfile.baremetal`（`DOMAIN` + 反代到 `127.0.0.1:3000`）。  
- Docker 仅跑 Caddy、二进制跑 systemd 也是一种组合，按你的运维规范选择。

## 8. Cloudflare Tunnel（无公网入口）

与 Docker 方案类似：Tunnel 连接器跑在主机上，源站指向 **`http://127.0.0.1:3000`**（systemd 监听本机回环时）。

## 9. GitHub Actions 一键发布

仓库工作流：`.github/workflows/release-new-api.yml`。

- **上游版本文件**：`release/upstream-ref.txt`  
  - 写入具体 tag/commit（推荐生产钉死），或写入 **`latest`**（解析为 QuantumNous/new-api 的 **GitHub Latest Release** tag）。  
- **推荐发布方式**：在本仓库打标签并推送 → 自动生成 Release 并上传构件：
  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```
  Release 标题使用标签名；构件内含 `linux/amd64`、`linux/arm64` 的 tarball 及 `SHA256SUMS.txt`。  
- **手动试构建**：Actions → **release-new-api** → Run workflow；可不勾选发布，仅在 Run 里下载 Artifact。  
- **手动发 GitHub Release**：勾选 `publish_release`，填写 `release_tag`（若标签已存在，`gh release create` 可能失败，可先删除旧草稿 Release）。

交叉编译使用 **`CGO_ENABLED=0`**，与上游默认 **glebarez/sqlite** 一致。

## 10. 其它发布习惯

- **构件**：为每个 release 保存二进制哈希、构建命令、`go version`、上游 **git tag**。  
- **数据库迁移**：关注上游 release notes；大版本升级前做备份与演练。  
- **密钥**：`SESSION_SECRET` / `CRYPTO_SECRET`（Redis）/ 上游渠道密钥全部走密钥管理，不落 Git。

## 11. 与本仓库其它文件的关系

- `deploy/docker-compose*.yml`：**可选**编排（适合你临时对齐镜像行为或混合部署）。  
- `deploy/Caddyfile`：面向「Caddy 与 New API 同 Compose 网络」；裸机请用 `deploy/Caddyfile.baremetal`。
