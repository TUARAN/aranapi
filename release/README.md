# 发布配置（aranapi）

## `upstream-ref.txt`

一行文本，指定要从 **[QuantumNous/new-api](https://github.com/QuantumNous/new-api)** 检出构建的 **tag、分支名或 commit SHA**。

- 写入 **`latest`**：在 CI 中会解析为该仓库 **GitHub Releases 页面的 Latest** 对应的 `tag_name`（不是你本地的最新提交）。
- 生产环境建议在发版前改成 **明确的上游 tag**，便于审计与回滚。

触发方式见仓库根目录 `README.md` 的「一键发布」与 `docs/production.md` 第 9 节。
