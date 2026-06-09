# 《Lost Miracle：亡灵地牢》

中文名：

# 《失落奇迹：亡灵地牢》

------

# 一、MVP 核心目标

第一版只验证一个问题：

> 玩家是否愿意反复刷怪、捡装备、强化装备、提升战力，然后挑战更强怪物。

所以 MVP 不做这些：

```text
不做大地图
不做角色行走
不做攻击动画
不做联网
不做复杂剧情
不做多职业
不做交易系统
不做任务系统
```

只做最小闭环：

```text
进入地牢
→ 点击探索
→ 遇到怪物
→ 战斗
→ 掉落装备
→ 穿戴装备
→ 强化装备
→ 战力提升
→ 挑战 Boss
→ 通关第一层
```

------

# 二、游戏类型设计

## 玩法类型

建议做成：

> **静态图暗黑刷装 RPG + 半挂机战斗**

玩家不是操控角色移动，而是在地牢中进行节点探索。

主界面大概是：

```text
┌────────────────────────────┐
│        亡灵地牢 1 层         │
├────────────────────────────┤
│                            │
│  玩家立绘        怪物立绘    │
│                            │
│  HP 1200       HP 850       │
│  MP 300        怪物状态      │
│                            │
├────────────────────────────┤
│ 普攻  重击  战吼  药水       │
├────────────────────────────┤
│ 战斗日志                    │
│ 你造成 120 点伤害            │
│ 骷髅士兵造成 35 点伤害        │
└────────────────────────────┘
```

------

# 三、MVP 内容规模

第一版内容量控制在这个范围内：

| 模块     | 数量      |
| -------- | --------- |
| 玩家职业 | 1 个      |
| 地牢层数 | 1 层      |
| 普通怪   | 3 个      |
| 精英怪   | 2 个      |
| Boss     | 1 个      |
| 主动技能 | 3 个      |
| 被动技能 | 2 个      |
| 装备部位 | 6 个      |
| 装备品质 | 5 档      |
| 套装     | 3 套      |
| 强化等级 | +0 到 +10 |
| 地牢事件 | 5 类      |

这个规模比较适合 Godot 单人开发 MVP。

------

# 四、地牢设计

## 亡灵地牢 1 层

不做真实地图，做“探索事件池”。

玩家点击：

```text
继续探索
```

系统随机触发事件：

| 事件类型  | 概率 | 说明                 |
| --------- | ---- | -------------------- |
| 普通怪    | 55%  | 主要刷装备来源       |
| 精英怪    | 15%  | 掉落更好装备         |
| 宝箱      | 10%  | 掉金币、强化石、装备 |
| 祭坛      | 10%  | 临时增益             |
| 陷阱      | 5%   | 扣血或负面状态       |
| Boss 入口 | 5%   | 条件满足后出现       |

Boss 入口可以设置条件：

```text
击败 15 只普通怪
击败 3 只精英怪
角色等级达到 5
```

这样玩家有短期目标。

------

# 五、怪物设计

## 普通怪

| 名称     | 定位     | 特点           |
| -------- | -------- | -------------- |
| 腐烂骷髅 | 标准近战 | 属性均衡       |
| 地牢僵尸 | 血厚怪   | HP 高，攻击低  |
| 亡魂法师 | 远程法术 | 攻击高，防御低 |

## 精英怪

| 名称     | 定位       | 特点           |
| -------- | ---------- | -------------- |
| 骸骨守卫 | 防御型精英 | 高防御，低速度 |
| 血影怨灵 | 爆发型精英 | 高暴击，高闪避 |

## Boss

| 名称            | 定位            |
| --------------- | --------------- |
| 地牢领主·莫尔甘 | 第一层最终 Boss |

Boss 技能：

| 技能     | 效果                            |
| -------- | ------------------------------- |
| 骸骨重击 | 对玩家造成 180% 攻击伤害        |
| 亡灵护盾 | 3 回合内防御提升 50%            |
| 死亡凝视 | 降低玩家 20% 攻击，持续 3 回合  |
| 终焉斩击 | 血量低于 30% 后释放，高伤害技能 |

------

# 六、战斗系统

建议第一版做 **回合制自动战斗 + 手动技能释放**。

## 战斗规则

```text
双方按速度决定行动顺序
普通攻击自动释放
玩家可以手动点击技能
技能有冷却时间
怪物 AI 根据技能冷却自动释放
一方 HP 归零，战斗结束
```

## 玩家基础属性

```text
生命值 HP
魔法值 MP
攻击力 ATK
防御力 DEF
速度 SPD
暴击率 CRIT_RATE
暴击伤害 CRIT_DMG
吸血 LIFESTEAL
闪避 DODGE
命中 HIT
```

## 伤害公式

第一版保持简单：

```text
最终伤害 = max(1, 攻击方攻击力 - 防御方防御力 * 0.5)
```

暴击：

```text
暴击伤害 = 最终伤害 * 暴击伤害倍率
```

比如默认暴击倍率是 150%。

------

# 七、玩家技能

第一版做 3 个主动技能 + 2 个被动技能。

## 主动技能

| 技能     | 效果                                  | 冷却   |
| -------- | ------------------------------------- | ------ |
| 重击     | 造成 150% 攻击伤害                    | 2 回合 |
| 战吼     | 攻击力提升 20%，持续 3 回合           | 5 回合 |
| 血性斩击 | 造成 120% 伤害，并恢复伤害值 10% 生命 | 4 回合 |

## 被动技能

| 技能     | 效果            |
| -------- | --------------- |
| 战士体魄 | 最大生命值 +10% |
| 武器精通 | 攻击力 +8%      |

------

# 八、装备系统

## 装备部位

第一版 6 个部位就够：

```text
武器
头盔
胸甲
护手
戒指
项链
```

## 装备品质

| 品质 | 颜色 | 词条数量 |
| ---- | ---- | -------- |
| 普通 | 白色 | 1        |
| 精良 | 绿色 | 2        |
| 稀有 | 蓝色 | 3        |
| 史诗 | 紫色 | 4        |
| 传说 | 橙色 | 5        |

## 装备属性池

```text
攻击力
防御力
生命值
暴击率
暴击伤害
吸血
速度
技能伤害
对亡灵增伤
受到伤害降低
```

## 掉落规则

| 怪物类型 | 掉落                   |
| -------- | ---------------------- |
| 普通怪   | 普通、精良、小概率稀有 |
| 精英怪   | 精良、稀有、小概率史诗 |
| Boss     | 稀有、史诗、小概率传说 |

------

# 九、强化系统

强化等级：

```text
+0 到 +10
```

强化消耗：

```text
金币
强化石
```

强化成功率：

| 等级 | 成功率 |
| ---- | ------ |
| +1   | 100%   |
| +2   | 100%   |
| +3   | 100%   |
| +4   | 85%    |
| +5   | 80%    |
| +6   | 70%    |
| +7   | 60%    |
| +8   | 50%    |
| +9   | 40%    |
| +10  | 30%    |

MVP 阶段建议：

```text
失败不掉级
失败只消耗材料
```

不要一开始做爆装、降级，挫败感太强。

------

# 十、套装系统

第一版做 3 套。

## 1. 亡灵猎手套装

定位：刷亡灵怪。

```text
2 件：对亡灵怪伤害 +10%
4 件：击杀亡灵怪后恢复 5% 最大生命
6 件：对 Boss 伤害 +15%
```

## 2. 黑铁守卫套装

定位：高防御。

```text
2 件：防御力 +10%
4 件：最大生命 +15%
6 件：受到伤害降低 12%
```

## 3. 血誓狂战套装

定位：暴击吸血。

```text
2 件：暴击率 +8%
4 件：吸血 +5%
6 件：生命低于 30% 时，攻击力 +30%
```

------

# 十一、Godot 项目结构

建议使用 **Godot 4.x + GDScript**。

项目结构可以这样设计：

```text
res://
├── scenes/
│   ├── main/
│   │   └── Main.tscn
│   ├── battle/
│   │   ├── BattleScene.tscn
│   │   ├── CharacterView.tscn
│   │   ├── MonsterView.tscn
│   │   └── DamageNumber.tscn
│   ├── dungeon/
│   │   └── DungeonScene.tscn
│   ├── inventory/
│   │   ├── InventoryScene.tscn
│   │   └── EquipmentSlot.tscn
│   ├── enhance/
│   │   └── EnhanceScene.tscn
│   └── ui/
│       ├── TopBar.tscn
│       ├── BattleLog.tscn
│       └── RewardPopup.tscn
│
├── scripts/
│   ├── autoload/
│   │   ├── Game.gd
│   │   ├── PlayerData.gd
│   │   ├── SaveManager.gd
│   │   └── DataManager.gd
│   ├── battle/
│   │   ├── BattleManager.gd
│   │   ├── BattleUnit.gd
│   │   ├── Skill.gd
│   │   └── DamageCalculator.gd
│   ├── dungeon/
│   │   ├── DungeonManager.gd
│   │   └── DungeonEvent.gd
│   ├── item/
│   │   ├── Equipment.gd
│   │   ├── ItemGenerator.gd
│   │   └── LootManager.gd
│   └── ui/
│       └── UIHelper.gd
│
├── data/
│   ├── monsters.json
│   ├── skills.json
│   ├── equipment_base.json
│   ├── affixes.json
│   ├── sets.json
│   └── dungeon_events.json
│
├── assets/
│   ├── characters/
│   ├── monsters/
│   ├── backgrounds/
│   ├── equipment/
│   ├── effects/
│   └── ui/
│
└── saves/
```

------

# 十二、核心 Scene 设计

## 1. Main.tscn

主入口。

包含：

```text
开始游戏
继续游戏
设置
退出
```

## 2. DungeonScene.tscn

地牢探索界面。

节点结构：

```text
DungeonScene
├── Background
├── PlayerInfoPanel
├── DungeonInfoPanel
├── ExploreButton
├── InventoryButton
├── EnhanceButton
├── BattleButton
└── EventResultPopup
```

核心功能：

```text
点击探索
随机事件
进入战斗
获得宝箱
触发陷阱
进入 Boss
```

## 3. BattleScene.tscn

战斗界面。

节点结构：

```text
BattleScene
├── Background
├── PlayerView
│   ├── PlayerSprite
│   ├── PlayerHpBar
│   └── PlayerStatusIcons
├── MonsterView
│   ├── MonsterSprite
│   ├── MonsterHpBar
│   └── MonsterStatusIcons
├── SkillBar
├── BattleLog
├── DamageNumberLayer
└── RewardPopup
```

表现方式：

```text
攻击：角色图片向前轻微位移
受击：目标闪白 + 震动
暴击：屏幕震动 + 大号伤害数字
技能：叠加一张 PNG 特效图
死亡：怪物淡出
```

这就是静态图 RPG 的核心表现力。

------

# 十三、数据文件设计

## monsters.json

示例：

```json
[
  {
    "id": "rotting_skeleton",
    "name": "腐烂骷髅",
    "type": "normal",
    "level": 1,
    "hp": 300,
    "atk": 35,
    "def": 10,
    "spd": 10,
    "crit_rate": 0.05,
    "crit_dmg": 1.5,
    "image": "res://assets/monsters/rotting_skeleton.png",
    "skills": []
  },
  {
    "id": "dungeon_lord_morgan",
    "name": "地牢领主·莫尔甘",
    "type": "boss",
    "level": 5,
    "hp": 3000,
    "atk": 120,
    "def": 45,
    "spd": 12,
    "crit_rate": 0.1,
    "crit_dmg": 1.8,
    "image": "res://assets/monsters/dungeon_lord_morgan.png",
    "skills": ["bone_slam", "undead_shield", "death_gaze"]
  }
]
```

## skills.json

```json
[
  {
    "id": "heavy_strike",
    "name": "重击",
    "type": "active",
    "mp_cost": 20,
    "cooldown": 2,
    "damage_multiplier": 1.5,
    "target": "enemy",
    "effect_image": "res://assets/effects/heavy_strike.png"
  },
  {
    "id": "battle_roar",
    "name": "战吼",
    "type": "active",
    "mp_cost": 30,
    "cooldown": 5,
    "target": "self",
    "buff": {
      "atk_percent": 0.2,
      "duration": 3
    },
    "effect_image": "res://assets/effects/battle_roar.png"
  }
]
```

## equipment_base.json

```json
[
  {
    "id": "iron_sword",
    "name": "铁剑",
    "slot": "weapon",
    "base_atk": 20,
    "base_def": 0,
    "base_hp": 0
  },
  {
    "id": "bone_helmet",
    "name": "骸骨头盔",
    "slot": "helmet",
    "base_atk": 0,
    "base_def": 12,
    "base_hp": 80
  }
]
```

## affixes.json

```json
[
  {
    "id": "atk_flat",
    "name": "攻击力",
    "stat": "atk",
    "min": 5,
    "max": 30
  },
  {
    "id": "crit_rate",
    "name": "暴击率",
    "stat": "crit_rate",
    "min": 0.01,
    "max": 0.08
  },
  {
    "id": "lifesteal",
    "name": "吸血",
    "stat": "lifesteal",
    "min": 0.01,
    "max": 0.06
  }
]
```

------

# 十四、核心脚本职责

## Game.gd

全局状态管理。

```text
当前场景
当前地牢
游戏状态
切换场景
全局事件派发
```

## PlayerData.gd

玩家数据。

```text
等级
经验
金币
强化石
当前装备
背包
基础属性
最终属性计算
```

## DataManager.gd

加载 JSON 数据。

```text
加载怪物数据
加载技能数据
加载装备数据
加载词条数据
加载套装数据
```

## BattleManager.gd

战斗流程。

```text
初始化战斗
决定行动顺序
执行普通攻击
执行技能
计算伤害
更新血条
判断胜负
生成奖励
```

## LootManager.gd

掉落逻辑。

```text
根据怪物类型决定品质
生成装备基础模板
随机词条
随机数值
返回掉落结果
```

## ItemGenerator.gd

装备生成。

```text
生成装备 ID
确定品质
确定词条数量
生成词条
计算装备最终属性
```

## SaveManager.gd

存档。

```text
保存玩家数据
读取玩家数据
自动存档
删除存档
```

------

# 十五、Godot Autoload 建议

建议把这些注册为 Autoload：

```text
Game.gd
PlayerData.gd
DataManager.gd
SaveManager.gd
```

这样所有场景都可以直接访问：

```gdscript
PlayerData.gold += 100
DataManager.get_monster("rotting_skeleton")
SaveManager.save_game()
Game.change_scene("res://scenes/dungeon/DungeonScene.tscn")
```

------

# 十六、MVP 开发顺序

## 第 1 阶段：项目骨架

目标：能打开游戏并进入地牢界面。

完成：

```text
创建 Godot 项目
创建 Main.tscn
创建 DungeonScene.tscn
创建基础 UI
创建 Autoload
实现切换场景
```

验收标准：

```text
点击开始游戏，可以进入亡灵地牢界面
```

------

## 第 2 阶段：数据系统

目标：能从 JSON 加载怪物、技能、装备数据。

完成：

```text
DataManager.gd
monsters.json
skills.json
equipment_base.json
affixes.json
```

验收标准：

```text
控制台可以打印指定怪物数据
点击按钮可以生成一件随机装备
```

------

## 第 3 阶段：战斗系统

目标：能打一只怪。

完成：

```text
BattleScene.tscn
BattleManager.gd
BattleUnit.gd
DamageCalculator.gd
HP Bar
战斗日志
伤害数字
胜负判断
```

验收标准：

```text
进入战斗后，玩家和怪物自动互相攻击
怪物死亡后返回地牢界面
玩家死亡后显示失败
```

------

## 第 4 阶段：掉落系统

目标：打怪能掉装备。

完成：

```text
LootManager.gd
ItemGenerator.gd
RewardPopup.tscn
装备品质
随机词条
装备基础属性
```

验收标准：

```text
击败怪物后弹出奖励
奖励可以进入背包
```

------

## 第 5 阶段：背包和穿戴

目标：玩家可以装备物品并提升属性。

完成：

```text
InventoryScene.tscn
EquipmentSlot.tscn
装备穿戴逻辑
属性重新计算
装备详情面板
```

验收标准：

```text
穿戴武器后，玩家攻击力提升
战斗伤害随之提升
```

------

## 第 6 阶段：强化系统

目标：可以强化装备。

完成：

```text
EnhanceScene.tscn
强化消耗
强化成功率
强化属性提升
金币和强化石扣除
```

验收标准：

```text
装备 +1 后属性提升
金币和强化石减少
强化结果能保存
```

------

## 第 7 阶段：地牢探索和 Boss

目标：完成第一层闭环。

完成：

```text
随机探索事件
普通怪事件
精英怪事件
宝箱事件
陷阱事件
Boss 入口
Boss 战
通关结果
```

验收标准：

```text
玩家可以从 0 开始探索，刷怪，掉装，强化，最终击败 Boss
```

------

# 十七、存档结构

Godot 可以先用本地 JSON 存档。

路径：

```text
user://save.json
```

存档内容：

```json
{
  "player": {
    "level": 3,
    "exp": 120,
    "gold": 500,
    "enhance_stone": 12,
    "base_stats": {
      "hp": 1000,
      "mp": 200,
      "atk": 80,
      "def": 30,
      "spd": 10,
      "crit_rate": 0.05,
      "crit_dmg": 1.5
    }
  },
  "equipment": {
    "weapon": "item_001",
    "helmet": null,
    "armor": null,
    "gloves": null,
    "ring": null,
    "necklace": null
  },
  "inventory": [
    {
      "uid": "item_001",
      "base_id": "iron_sword",
      "name": "稀有的铁剑",
      "slot": "weapon",
      "quality": "rare",
      "enhance_level": 2,
      "affixes": [
        {
          "stat": "atk",
          "value": 18
        },
        {
          "stat": "crit_rate",
          "value": 0.03
        }
      ]
    }
  ],
  "dungeon": {
    "floor": 1,
    "normal_kill_count": 12,
    "elite_kill_count": 2,
    "boss_defeated": false
  }
}
```

------

# 十八、静态图战斗表现方案

虽然是全静态图，但要有反馈。

## 普通攻击

```text
玩家立绘向前移动 12px
怪物立绘闪白
怪物轻微震动
飘出伤害数字
播放攻击音效
```

## 技能释放

```text
技能名弹出
屏幕轻微暗化
技能特效 PNG 叠加到目标身上
伤害数字变大
战斗日志追加说明
```

## 暴击

```text
屏幕震动
伤害数字放大
显示 CRITICAL
播放重击音效
```

## 死亡

```text
怪物透明度逐渐降低
掉落弹窗出现
战斗日志显示胜利
```

Godot 实现这些很简单，用：

```text
Tween
AnimationPlayer
CanvasLayer
Label
TextureRect
ProgressBar
```

不需要 SpriteSheet 动画。

------

# 十九、MVP UI 页面清单

第一版只需要 6 个页面。

| 页面     | 用途             |
| -------- | ---------------- |
| 主菜单   | 开始/继续游戏    |
| 地牢页面 | 探索、事件入口   |
| 战斗页面 | 玩家 vs 怪物     |
| 背包页面 | 查看、穿戴、分解 |
| 强化页面 | 强化装备         |
| 通关页面 | Boss 击败结算    |

不要一开始做太多页面。

------

# 二十、第一版美术资源需求

全静态图版本美术压力很低。

## 必需资源

```text
玩家战士立绘 × 1
普通怪立绘 × 3
精英怪立绘 × 2
Boss 立绘 × 1
地牢背景图 × 1
战斗背景图 × 1
装备图标 × 30
技能图标 × 3
技能特效 PNG × 5
UI 面板素材 × 若干
```

## 可以先用占位图

第一版开发时可以先用：

```text
纯色方块
免费图标
AI 生成草图
临时 UI
```

不要让美术阻塞玩法闭环。

------

# 二十一、推荐优先级

## 必须做

```text
战斗
掉落
背包
穿戴
强化
Boss
存档
```

## 可以后做

```text
音效
更多怪物
更多装备
套装
剧情
图鉴
成就
离线收益
多职业
```

## 暂时不要做

```text
联网
PVP
交易行
地图编辑器
复杂任务系统
大型剧情分支
多端同步
```

------

# 二十二、MVP 验收标准

第一版完成时，应该满足这些标准：

```text
1. 玩家可以开始新游戏
2. 玩家可以进入亡灵地牢 1 层
3. 玩家可以点击探索触发事件
4. 玩家可以和怪物战斗
5. 怪物死亡后可以掉落装备
6. 装备可以进入背包
7. 装备可以穿戴
8. 穿戴装备后属性发生变化
9. 装备可以强化
10. 强化后战斗力提升
11. 玩家可以挑战 Boss
12. Boss 死亡后显示第一层通关
13. 游戏可以保存和读取
```

只要这 13 条成立，MVP 就成立。

------

# 二十三、建议的第一版开发排期

你可以按 10 个小任务推进：

```text
Task 01：创建 Godot 项目和基础 UI
Task 02：实现 DataManager 加载 JSON
Task 03：实现 PlayerData 和属性计算
Task 04：实现 BattleScene 基础战斗
Task 05：实现怪物数据和技能释放
Task 06：实现掉落和随机装备生成
Task 07：实现背包和装备穿戴
Task 08：实现装备强化
Task 09：实现地牢探索事件
Task 10：实现 Boss 战和通关结算
```

------

# 二十四、给 Coding Agent 的交接 Prompt

你可以直接把下面这段交给 Claude Code / Qwen Code / Codex：

```text
你是一个资深 Godot 4.x 游戏工程师。请帮我实现一款全静态图暗黑刷装 RPG 的 MVP，项目名称为 Lost Miracle: Undead Dungeon。

开发目标：
实现一个单机 Godot 4.x + GDScript 项目，核心闭环是：
进入地牢 → 点击探索 → 遇到怪物 → 回合制自动战斗 → 掉落装备 → 背包查看 → 穿戴装备 → 强化装备 → 提升战力 → 挑战 Boss → 通关第一层。

技术要求：
1. 使用 Godot 4.x。
2. 使用 GDScript。
3. 不做联网。
4. 不做真实地图移动。
5. 不做角色帧动画。
6. 使用静态 TextureRect / Sprite2D 展示角色和怪物。
7. 使用 Tween、闪白、震动、伤害数字、技能特效 PNG 来表现战斗反馈。
8. 游戏数据使用 JSON 管理。
9. 存档使用 user://save.json。
10. 代码结构清晰，便于后续扩展。

请创建以下目录结构：

res://
├── scenes/
│   ├── main/Main.tscn
│   ├── dungeon/DungeonScene.tscn
│   ├── battle/BattleScene.tscn
│   ├── inventory/InventoryScene.tscn
│   ├── enhance/EnhanceScene.tscn
│   └── ui/
├── scripts/
│   ├── autoload/Game.gd
│   ├── autoload/PlayerData.gd
│   ├── autoload/DataManager.gd
│   ├── autoload/SaveManager.gd
│   ├── battle/BattleManager.gd
│   ├── battle/BattleUnit.gd
│   ├── battle/DamageCalculator.gd
│   ├── dungeon/DungeonManager.gd
│   ├── item/Equipment.gd
│   ├── item/ItemGenerator.gd
│   ├── item/LootManager.gd
│   └── ui/UIHelper.gd
├── data/
│   ├── monsters.json
│   ├── skills.json
│   ├── equipment_base.json
│   ├── affixes.json
│   ├── sets.json
│   └── dungeon_events.json
└── assets/
    ├── characters/
    ├── monsters/
    ├── backgrounds/
    ├── equipment/
    ├── effects/
    └── ui/

核心系统要求：

一、玩家系统
玩家有以下属性：
hp, max_hp, mp, max_mp, atk, def, spd, crit_rate, crit_dmg, lifesteal, dodge, hit。
支持基础属性 + 装备属性 + 套装属性的最终属性计算。

二、怪物系统
实现 3 个普通怪、2 个精英怪、1 个 Boss：
1. 腐烂骷髅
2. 地牢僵尸
3. 亡魂法师
4. 骸骨守卫
5. 血影怨灵
6. 地牢领主·莫尔甘

三、战斗系统
实现回合制自动战斗：
1. 根据速度决定行动顺序。
2. 普通攻击自动释放。
3. 玩家可以手动点击技能。
4. 技能有冷却。
5. 怪物可以释放技能。
6. 伤害公式为：max(1, attacker.atk - defender.def * 0.5)。
7. 支持暴击。
8. 支持吸血。
9. 战斗结束后返回地牢页面或显示奖励。

四、技能系统
玩家主动技能：
1. 重击：造成 150% 攻击伤害，冷却 2 回合。
2. 战吼：攻击力提升 20%，持续 3 回合，冷却 5 回合。
3. 血性斩击：造成 120% 攻击伤害，并恢复伤害值 10% 生命，冷却 4 回合。

五、装备系统
装备部位：
weapon, helmet, armor, gloves, ring, necklace。

装备品质：
common, fine, rare, epic, legendary。

每件装备包含：
uid, base_id, name, slot, quality, enhance_level, base_stats, affixes, set_id。

装备词条包括：
atk, def, hp, crit_rate, crit_dmg, lifesteal, spd, skill_damage, undead_damage。

六、掉落系统
普通怪掉落普通、精良、小概率稀有。
精英怪掉落精良、稀有、小概率史诗。
Boss 掉落稀有、史诗、小概率传说。

七、强化系统
装备可强化到 +10。
强化消耗金币和强化石。
失败不降级，只消耗材料。
强化后提升装备基础属性。

八、地牢探索系统
DungeonScene 有“继续探索”按钮。
点击后随机触发：
普通怪、精英怪、宝箱、祭坛、陷阱、Boss 入口。
Boss 入口需要满足：
普通怪击杀数 >= 15，精英怪击杀数 >= 3。

九、存档系统
使用 user://save.json 保存：
玩家等级、经验、金币、强化石、背包、当前穿戴装备、地牢进度。

十、UI 要求
先使用简洁占位 UI 即可。
需要有：
主菜单、地牢页面、战斗页面、背包页面、强化页面、奖励弹窗、战斗日志。

请按以下阶段实现：
1. 搭建项目目录和 Autoload。
2. 实现 JSON 数据加载。
3. 实现玩家数据和存档。
4. 实现战斗系统。
5. 实现掉落系统。
6. 实现背包和装备穿戴。
7. 实现强化系统。
8. 实现地牢探索。
9. 实现 Boss 战和通关结算。

实现时请优先保证 MVP 闭环完整，不要过度设计。每完成一个阶段，请提供可运行验证方法。
```

------

# 最终建议

这个 Godot MVP 的关键不是“画面多丰富”，而是先把这条链路做顺：

```text
探索 → 战斗 → 掉装 → 穿戴 → 强化 → 战力提升 → 打 Boss
```

只要这条闭环成立，后面你再加：

```text
第二层地牢
多职业
装备套装
离线挂机
技能树
图鉴
剧情事件
```

都很自然。

第一版建议就叫：

> **《失落奇迹：亡灵地牢》MVP**

技术定位：

> **Godot 4.x 单机静态图刷装 RPG。**