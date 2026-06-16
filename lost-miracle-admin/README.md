# Lost Miracle Admin

GM Web 管理台（Vite + React + Ant Design）。

## 开发

```bash
# 需先启动 lost-miracle-server (8080)
npm install
npm run dev
```

浏览器打开 `http://127.0.0.1:5173`，默认 GM 账号见服务端 `application.yml` 中 `lost-miracle.gm.*`。

Vite 开发服务器会将 `/api` 代理到 `http://127.0.0.1:8080`。

## 生产部署

```bash
npm run build
# dist/ 由 Nginx 托管，仅内网/VPN 访问
```

Nginx 需同时反代 `/api/v1/admin` 到 Spring Boot。

## 功能

- 玩家搜索 / 角色存档编辑（字段 + 完整 JSON 二次确认）
- 刷怪槽查看与重置
- 配置中心（掉率、探索权重、强化规则等）草稿 + 发布
- 审计日志

详见 [`../docs/GM_ADMIN.md`](../docs/GM_ADMIN.md)。
