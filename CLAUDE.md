# CLAUDE.md

Monorepo 开发指引。**玩法见 [`docs/DESIGN.md`](docs/DESIGN.md)**，**服务端见 [`docs/BACKEND_ARCHITECTURE.md`](docs/BACKEND_ARCHITECTURE.md)**。

## Repository Layout

```text
lost-miracle-client/   ← Godot 项目根（project.godot）
lost-miracle-server/   ← Spring Boot API
docs/
```

## Client (`lost-miracle-client/`)

**失落奇迹：亡灵地牢** — 静态图刷装 RPG + 实时半挂机战斗（1280×720，Godot 4.6.2，GDScript）。

```
login/ → scenes/main/ → map/ → dungeon/ ⇄ battle/
                              ↕
                         inventory/ (+ enhance inline)
```

Autoloads: `Game`, `PlayerData`, `DataManager`, `SaveManager`, `NetworkManager`, `CloudSaveService`, `ConnectivityMonitor`

### Current Scope

- **Combat**: Real-time, attack speed based; manual skills 1/2/3; battle roar = global +20% atk spd for 300s
- **Class**: Warrior only for new game; 4 classes in data for future
- **Equipment**: 8 slots (dual rings), vine/chain/plate tiers, +0~+10 enhance (**stones only, no gold**)
- **Rings/Necklace**: swamp rings, forge jewelry stones, frozen necklaces — see `docs/DESIGN.md` §11
- **Dungeon**: 4 maps; explore 75/10/10/5; global spawn slots (normal×3/type 60s, elite 180s, boss 300s)
- **Save**: **Online-only** — must login + network; cloud is sole persistence (`CloudSaveService`); `SaveManager` is in-memory serialize only; local disk keeps JWT only (`user://auth_token.json`)

### Key Formulas

```
damage = max(1, ATK - DEF * 0.5)
exp_required = level² * 50
```

Data: `lost-miracle-client/data/*.json`

Controls: Tab=inventory, R=enhance, 1/2/3=skills, 4=potion

## Server (`lost-miracle-server/`)

JDK 17 + Spring Boot 3 + MySQL + Redis. Base URL: `http://127.0.0.1:8080/api/v1`

## Docs

| File | Purpose |
|------|---------|
| `docs/DESIGN.md` | 玩法设计文档 |
| `docs/BACKEND_ARCHITECTURE.md` | 服务端架构 |
| `lost-miracle-client/README.md` | 客户端说明 |
| `lost-miracle-server/README.md` | 服务端说明 |
