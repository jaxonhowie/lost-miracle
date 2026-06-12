# Lost Miracle Client

Godot 4.6.2 客户端 — **失落奇迹：亡灵地牢**。

## 打开项目

1. 安装 [Godot 4.6.2](https://godotengine.org/)
2. **Import** → 选择本目录下的 `project.godot`
3. 运行主场景 `scenes/main/Main.tscn`

> 必须在 **`lost-miracle-client/`** 目录作为项目根打开，不要使用上级 monorepo 根目录。

## 目录结构

```text
lost-miracle-client/
├── project.godot
├── scenes/          UI 场景
├── scripts/         GDScript（autoload、battle、dungeon、item）
├── data/            JSON 配置
├── assets/          美术资源（预留）
└── addons/          编辑器插件
```

## 分辨率与操作

- 1280×720
- Tab 背包 · R 强化 · 1/2/3 技能 · 4 药水

玩法设计见 [`../docs/DESIGN.md`](../docs/DESIGN.md)。

## 联网（规划）

HTTP + JSON 对接 `lost-miracle-server`，客户端网络模块将置于 `scripts/network/`。
