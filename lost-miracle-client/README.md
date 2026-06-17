# Lost Miracle Client

Godot 4.6.2 客户端 — **失落奇迹：亡灵地牢**。

## 打开项目

1. 安装 [Godot 4.6.2](https://godotengine.org/)
2. **Import** → 选择本目录下的 `project.godot`
3. **先启动服务端**（见 [`../lost-miracle-server/README.md`](../lost-miracle-server/README.md)）
4. 运行主场景 `scenes/main/Main.tscn`（未登录会自动跳转 `scenes/login/LoginScene.tscn`）

> 必须在 **`lost-miracle-client/`** 目录作为项目根打开，不要使用上级 monorepo 根目录。

## 目录结构

```text
lost-miracle-client/
├── project.godot
├── scenes/          UI 场景（login、main、map、dungeon、battle、inventory）
├── scripts/         GDScript（autoload、network、battle、dungeon、item）
├── data/            JSON 配置
├── assets/          美术资源（预留）
└── addons/          编辑器插件
```

## 分辨率与操作

- 1280×720
- Tab 背包 · R 强化 · 1/2/3 技能 · 4 药水

玩法设计见 [`../docs/DESIGN.md`](../docs/DESIGN.md)。

## 联网与存档

本客户端为**必须登录、必须联网**的在线游戏。游戏进度只存服务端，客户端内存持有当前会话。

HTTP + JSON 对接 [`../lost-miracle-server`](../lost-miracle-server)（默认 `http://127.0.0.1:8080/api/v1`）。

| 模块 | 路径 |
|------|------|
| API 客户端 | `scripts/network/ApiClient.gd`、`ApiConfig.gd` |
| 登录态 | Autoload `NetworkManager` |
| 云存档 | `scripts/network/CloudSaveService.gd` |
| 连接探活 | `scripts/network/ConnectivityMonitor.gd` |
| 状态序列化 | Autoload `SaveManager`（内存 only，不写游戏档到磁盘） |

**登录态**：JWT 仅存于内存；**每次启动须重新登录**；登出 / 退出游戏 / 关闭窗口时调用 `POST /auth/logout` 注销 token（Redis 黑名单），并清理本地会话。启动时会删除旧版遗留的 `user://auth_token.json`（若存在）。

**同步**：战斗结算走服务端 `settle` API；背包操作、切场景等关键节点调用 `CloudSaveService.sync_to_cloud()`；自动战斗进战前跳过阻塞同步。失败时内存重试队列 + 指数退避，网络恢复后自动上传。切场景 / 登出 / 退出须同步成功，否则阻止离开。

**离线**：主菜单阻断进入；游戏中断网可继续玩，但无法切场景或登出直至恢复连接。
