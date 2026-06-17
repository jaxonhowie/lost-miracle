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
- **Save**: **Online-only** — must login + network; cloud is sole persistence (`CloudSaveService`); `SaveManager` is in-memory serialize only; **JWT 仅内存持有，退出/关闭客户端时注销，不写入磁盘**

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

## Karpathy Guidelines

来源：[Andrej Karpathy 对 LLM 编码陷阱的观察](https://x.com/karpathy/status/2015883857489522876)。**权衡：偏谨慎而非速度。简单任务自行判断。**

### 1. 先想再写

**不要假设。不要隐藏困惑。暴露权衡。**

- 明确陈述你的假设。不确定就问。
- 存在多种解读时，全部呈现——不要默默选一种。
- 有更简单的方案就说出来。该反驳就反驳。
- 不清楚就停下来，说清楚哪里不懂，然后问。

### 2. 简单优先

**能解决问题的最少代码。不做投机性设计。**

- 不加没被要求的功能。
- 不为只用一次的代码搞抽象。
- 不追求没要求的"灵活性"或"可配置性"。
- 不为不可能的场景写错误处理。
- 200 行能缩成 50 行，就重写。

自问："资深工程师会觉得这过度复杂吗？" 是就简化。

### 3. 精准修改

**只动必须动的。只清理自己造成的遗留。**

编辑现有代码时：
- 不要"顺手改进"旁边的代码、注释或格式。
- 不要重构没坏的东西。
- 匹配现有风格，即使你会写得不一样。
- 发现无关的死代码，提一句——不要删。

你的改动产生孤立引用时：
- 删除**你自己的改动**导致未使用的 import/变量/函数。
- 不删除原有的死代码（除非被要求）。

检验标准：每一行改动都能直接追溯到用户的需求。

### 4. 目标驱动执行

**定义成功标准。循环直到验证通过。**

将任务转化为可验证的目标：
- "加校验" → "为非法输入写测试，然后让它通过"
- "修 bug" → "写一个复现测试，然后让它通过"
- "重构 X" → "确保重构前后测试都通过"

多步任务给出简要计划：

```text
1. [步骤] → 验证：[检查项]
2. [步骤] → 验证：[检查项]
3. [步骤] → 验证：[检查项]
```

强成功标准让 AI 能独立循环。弱标准（"搞通就行"）则需要不断追问。
