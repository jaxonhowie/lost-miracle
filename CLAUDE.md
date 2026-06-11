# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**失落奇迹：亡灵地牢 (Lost Miracle: Undead Dungeon)** — 静态图暗黑刷装 RPG + 半挂机回合制战斗。玩家在地牢中点击探索，遭遇怪物进行回合制战斗，收集装备，强化装备，挑战 Boss 通关。

## Tech Stack

- **Engine**: Godot 4.6.2 stable
- **Language**: GDScript
- **Resolution**: 1280x720
- **Combat**: 回合制自动战斗 + 手动技能释放
- **表现**: 静态 TextureRect/ColorRect + Tween 动画

## Architecture

### Scene Structure

```
res://
  scenes/
    main/              — Main.tscn 主菜单
    dungeon/           — DungeonScene.tscn 地牢探索
    battle/            — BattleScene.tscn 战斗界面
    inventory/         — InventoryScene.tscn 背包
    enhance/           — EnhanceScene.tscn 强化
  scripts/
    autoload/          — Game, PlayerData, DataManager, SaveManager
    battle/            — BattleManager, BattleUnit, DamageCalculator, Skill
    dungeon/           — DungeonManager, DungeonEvent
    item/              — Equipment, ItemGenerator, LootManager
    ui/                — UIHelper
  data/                — JSON 数据文件
```

### Core Systems

- **Data-driven**: 所有怪物/技能/装备定义在 `data/` JSON 文件中
- **4 个 Autoload**: `Game`(全局状态), `PlayerData`(玩家数据), `DataManager`(JSON加载), `SaveManager`(存档)
- **装备实例**: 每件装备有唯一 UID、品质、强化等级、特效
- **回合制战斗**: 按速度决定行动顺序，自动普攻 + 手动技能
- **职业系统**: 战士/游侠/刺客/精灵 4个职业，各有主属性和成长路线
- **属性系统**: 每级+1主属性+每3级循环(副A→副B→主)，无手动分配

### Key Data Schemas

- **Equipment instance**: `{ uid, base_id, name, slot, quality, enhance_level, base_stats, set_id, effects }`
- **Monster**: `{ id, name, type, level, hp, atk, def, spd, crit_rate, crit_dmg, skills }`
- **Skill**: `{ id, name, type(active/passive/monster), mp_cost, cooldown, damage_multiplier, buff/debuff }`
- **Affix**: `{ id, name, stat, min, max }`

### Damage Formula

```
最终伤害 = max(1, 攻击方ATK - 防御方DEF * 0.5)
暴击伤害 = 最终伤害 * 暴击伤害倍率
吸血恢复 = 伤害值 * 吸血率
```

### Enhancement Rules

- +0 到 +10，消耗金币 + 强化石（普通或受祝福）
- 失败不降级，只消耗材料
- 两种强化石：普通强化石、受祝福强化石（受祝福成功率更高）
- 成功率（普通/受祝福）: +0→+1=100%/100%, +1→+2=100%/100%, +2→+3=100%/100%, +3→+4=30%/100%, +4→+5=28%/33%, +5→+6=20%/25%, +6→+7=18%/23%, +7→+8=15%/20%, +8→+9=13%/18%, +9→+10=10%/15%
- 金币消耗（阶梯式）: +0→+3=50金, +3→+5=100金, +5→+7=200金, +7→+9=500金, +9→+10=1000金
- Weapon: +1~+4 ATK+1/级, +5 ATK+2, +6~+10 ATK+3/级
- Armor/Helmet: +1~+5 DEF+1/级, +6~+7 DEF+2/级, +8~+10 DEF+3/级
- 特效解锁: +5=初级特效, +7=二级特效, +10=终极特效
- 品质变化: +0~+3=普通(白), +4~+6=精良(蓝), +7~+9=史诗(紫), +10=传说(橙)

### Dungeon Events

| 事件类型 | 概率 | 说明 |
|---------|------|------|
| 普通怪 | 50% | 主要刷装备来源 |
| 精英怪 | 20% | 掉落更好装备 |
| 宝箱 | 10% | 金币、强化石 |
| 祭坛 | 10% | 临时增益 |
| 陷阱 | 5% | 扣血 |
| Boss入口 | 5% | 需满足条件 |

Boss 入口条件: 击败 ≥15 普通怪, ≥3 精英怪, 等级 ≥5

### Equipment Quality

品质由强化等级决定，掉落时统一为普通品质：

| 品质 | 颜色 | 强化等级 | 属性倍率 |
|------|------|----------|----------|
| 普通 normal | 白色 | +0 ~ +3 | 1.0x |
| 精良 fine | 蓝色 | +4 ~ +6 | 1.15x |
| 史诗 epic | 紫色 | +7 ~ +9 | 1.60x |
| 传说 legendary | 橙色 | +10 | 1.85x |

### Sets (3 sets)

- **亡灵猎手**: 2件=亡灵伤害+10%, 4件=击杀回血5%, 6件=Boss伤害+15%
- **黑铁守卫**: 2件=防御+10%, 4件=生命+15%, 6件=受伤降低12%
- **血誓狂战**: 2件=暴击+8%, 4件=吸血+5%, 6件=低血量攻击+30%

### Save System

- 路径: `user://save.json`
- 保存: 等级、经验、金币、强化石、背包、装备、地牢进度

## Controls

| Action | Key |
|--------|-----|
| 技能 1/2/3 | 1 / 2 / 3 |
| 背包 | Tab |
| 强化 | R |
| 探索 | 鼠标点击按钮 |

## Development Order

1. 项目骨架 + Autoload
2. JSON 数据文件
3. 回合制战斗系统
4. 掉落 + 背包 + 装备穿戴
5. 强化系统
6. 地牢探索 + Boss
7. 主菜单 + 存档 + UI 收尾
