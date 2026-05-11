# 失落奇迹 (Lost Miracle) MVP 开发计划

## Context

基于 MVP-V1.md 设计文档，从零开始开发一个 2D 横版亡灵地牢刷装 RPG。引擎为 Godot 4.6.2，语言为 GDScript。目标是把"杀怪→掉落→装备→变强"核心循环跑通。

---

## 操作方案

| 操作 | 按键 |
|------|------|
| 移动 | A / D |
| 跳跃 | 空格 |
| 普通攻击 | 鼠标左键 |
| 技能 1 | 1 |
| 技能 2 | 2 |
| 技能 3 | 3 |
| 快捷物品栏第 1 格 | F1 |
| 打开/关闭背包 | Tab |

---

## 开发阶段

### Phase 1: 项目初始化与玩家基础

**目标**：角色能在地图里跑、跳、攻击。

1. 初始化 Godot 4.6.2 项目
   - 创建 `project.godot`，配置窗口 1280x720
   - 建立目录结构：`scenes/`, `scripts/`, `data/`
   - 配置物理层和碰撞层命名

2. 实现 Player 场景 (`scenes/player/Player.tscn` + `Player.gd`)
   - CharacterBody2D 基础节点结构
   - 左右移动（move_speed=180）
   - 跳跃（jump_velocity=-360）+ 重力
   - 动画状态机：Idle / Run / Jump / Attack / Hit / Death
   - 近战攻击 HitBox（48x32 矩形，0.45s 冷却）
   - 受击闪烁 + 击退
   - 死亡处理

3. 搭建临时测试地图
   - 静态平台 + 碰撞体
   - 摄像机跟随玩家（Camera2D + 限制边界）

**验证**：玩家能在地图中流畅移动、跳跃、攻击，动画切换正确。

---

### Phase 2: 怪物系统

**目标**：怪物能巡逻、追击、攻击、被击杀。

1. BaseMonster 基类 (`scenes/monsters/BaseMonster.tscn` + `BaseMonster.gd`)
   - CharacterBody2D
   - 状态机：Idle → Patrol → Chase → Attack → Hit → Dead
   - 感知区域（DetectionArea）+ 攻击区域（AttackArea）
   - 受击、死亡、掉落触发

2. 三种小怪
   - 骷髅兵：近战，HP=60，攻击=8，移速=80
   - 腐尸：近战慢速带击退，HP=100，攻击=10，移速=45
   - 幽魂：漂浮穿平台，HP=45，攻击=12，移速=120

3. 玩家与怪物的伤害交互
   - 伤害公式：`max(1, attack - defense)`
   - 暴击判定：crit_rate=0.05，crit_damage=1.5
   - 双方都能造成伤害和死亡

**验证**：3 种小怪行为各异，玩家能击杀怪物，怪物能伤害玩家。

---

### Phase 3: 掉落与背包系统

**目标**：怪物死亡掉东西，玩家能拾取，打开背包查看。

1. 数据层
   - `data/items.json`：所有物品定义（装备 + 材料）
   - `data/drops.json`：怪物掉落表
   - `scripts/data/ItemDatabase.gd`：物品数据 autoload
   - `scripts/data/DropTableDatabase.gd`：掉落表 autoload

2. 掉落系统 (`scripts/systems/DropSystem.gd`)
   - 怪物死亡时按掉落表随机生成物品
   - 掉落物场景 (`scenes/items/DropItem.tscn`)：弹出 → 落地 → 等待拾取
   - 金币直接加到玩家，装备/材料进背包

3. 背包系统 (`scripts/systems/InventorySystem.gd`)
   - 物品列表管理（材料可堆叠，装备独立 UID）
   - 背包 UI (`scenes/ui/InventoryPanel.tscn`)：格子列表 + 物品详情 + 操作按钮

4. 拾取交互
   - 玩家靠近掉落物自动拾取
   - 屏幕左侧显示获得物品提示

**验证**：击杀骷髅兵后掉落金币/材料/装备，自动拾取后背包中可见。

---

### Phase 4: 装备系统

**目标**：装备能穿上脱下，影响玩家属性。

1. 装备系统 (`scripts/systems/EquipmentSystem.gd`)
   - 4 个槽位：武器、衣服、鞋子、戒指
   - 穿戴/卸下逻辑
   - 属性重算：总攻击 = 基础 + 武器 + 强化

2. 装备栏 UI (`scenes/ui/EquipmentPanel.tscn`)
   - 4 个槽位显示当前装备
   - 右侧显示总攻击/防御/生命
   - 从背包点击"装备"按钮穿戴

3. 装备品质颜色
   - 普通=白、优秀=绿、稀有=蓝、史诗=紫

**验证**：穿不同装备后，HUD 上攻击/防御/生命数值变化正确。

---

### Phase 5: 强化系统

**目标**：装备可以从 +0 强化到 +10，有成功率和失败规则。

1. 强化系统 (`scripts/systems/EnhanceSystem.gd`)
   - 消耗金币 + 强化石材料
   - 成功率按等级递减（100%→25%）
   - 失败规则：+1~5 不降级，+6~8 降 1 级，+9~10 降 1 级不爆装
   - 属性成长：武器 +10% 攻击/级，防具 +8% 防御 +5% 生命/级

2. 强化 UI (`scenes/ui/EnhancePanel.tscn`)
   - 选择装备 → 显示当前等级和属性 → 显示强化后预览 → 显示消耗和成功率 → 强化按钮

**验证**：+5 武器攻击力比 +0 高 50%，+6 失败降回 +5。

---

### Phase 6: 精英怪与 Boss

**目标**：2 种精英和 1 个 Boss 可挑战，有独特技能。

1. 精英骷髅骑士（近战压迫型）
   - HP=450，攻击=24，防御=6
   - 技能：重斩（140% 伤害）、冲锋、格挡（-50% 伤害）
   - 掉落：骑士长剑、胸甲、强化石

2. 精英亡灵法师（远程法术型）
   - HP=360，攻击=30，防御=3
   - 技能：暗影箭（飞行弹幕）、召唤骷髅、灵魂爆裂（近身 AOE）
   - 掉落：亡灵法杖、法师披风、中级强化石

3. Boss 地牢守墓人（三阶段）
   - HP=1800，攻击=42，防御=10
   - P1（100%-60%）：挥砍、地裂冲击、冲锋
   - P2（60%-25%）：召唤骷髅、横扫、亡灵火焰
   - P3（25%-0%）：加速、三连斩、全屏落骨
   - 掉落：守墓人巨剑/重甲、Boss 强化核心、高级强化石

**验证**：精英和 Boss 有明显区别于小怪的行为模式，击杀后掉落正确。

---

### Phase 7: 地图与刷新系统

**目标**：正式搭建亡灵地牢 1 层，怪物按规则刷新。

1. 亡灵地牢 1 层地图 (`scenes/maps/DungeonFloor1.tscn`)
   - TileMapLayer 构建地形（4000-6000px 宽，1200-1600px 高）
   - 9 个区域：入口区 → 小怪区A → 分叉平台 → 精英区1 → 小怪区B → 陷阱走廊 → 精英区2 → Boss门 → Boss房
   - 碰撞层、平台层、装饰层分离
   - 陷阱：地刺、落石（可选）

2. 刷新系统 (`scripts/systems/SpawnSystem.gd`)
   - 刷怪点数据 (`data/spawns_dungeon_1.json`)
   - 小怪 60s 刷新，玩家距离 < 300px 不刷新，同区域上限 6
   - 精英 15min，Boss 1h
   - 每个刷怪点独立计时

3. 将玩家放入正式地图测试完整流程

**验证**：从入口跑到 Boss 房，沿途怪物分布正确，小怪死后 1 分钟刷新。

---

### Phase 8: 存档系统与 UI 收尾

**目标**：退出重进后数据不丢失，UI 完善。

1. 存档系统 (`scripts/systems/SaveSystem.gd`)
   - 存档内容：玩家等级/金币/HP、背包物品、装备栏、精英/Boss 死亡时间戳
   - JSON 格式读写 (`user://save.json`)
   - 进入游戏自动加载，关键操作自动保存

2. HUD (`scenes/ui/HUD.tscn`)
   - 左上：头像 + HP 条
   - 右上：金币数量
   - 底部：快捷栏（普攻图标）

3. 最终联调
   - 完整循环测试：进入地牢 → 杀怪 → 掉落 → 拾取 → 穿装 → 强化 → 杀精英 → 杀 Boss → 退出 → 重进验证存档

**验证**：退出游戏后重新进入，装备/金币/Boss 刷新时间与退出前一致。

---

## 场景与代码结构

```
res://
  project.godot
  scenes/
    player/
      Player.tscn
      Player.gd
    monsters/
      BaseMonster.tscn
      BaseMonster.gd
      SkeletonSoldier.tscn / .gd
      Zombie.tscn / .gd
      Ghost.tscn / .gd
      EliteSkeletonKnight.tscn / .gd
      EliteNecromancer.tscn / .gd
      GraveKeeperBoss.tscn / .gd
    maps/
      DungeonFloor1.tscn
      DungeonFloor1.gd
    items/
      DropItem.tscn
      DropItem.gd
    ui/
      HUD.tscn
      InventoryPanel.tscn
      EquipmentPanel.tscn
      EnhancePanel.tscn
  scripts/
    systems/          ← autoload 单例
      DropSystem.gd
      SpawnSystem.gd
      InventorySystem.gd
      EquipmentSystem.gd
      EnhanceSystem.gd
      SaveSystem.gd
    data/             ← autoload 单例
      ItemDatabase.gd
      MonsterDatabase.gd
      DropTableDatabase.gd
  data/               ← JSON 数据文件
    items.json
    monsters.json
    drops.json
    spawns_dungeon_1.json
```

---

## 关键实现要点

- **系统层用 autoload**：DropSystem、InventorySystem 等作为全局单例，场景通过 `get_node("/root/DropSystem")` 访问
- **数据驱动**：所有物品/怪物/掉落/刷怪点定义在 JSON，不在 GDScript 中硬编码
- **怪物继承**：BaseMonster 提供状态机和基础行为，子怪物只覆写攻击方式和属性
- **装备实例**：每件装备有唯一 UID + enhance_level，存档中独立存储
- **强化不爆装**：MVP 阶段不做装备损毁，降低劝退感
- **美术占位**：初期用 ColorRect/简单图形占位，不需要等美术资源

---

## 验证方式

每个 Phase 完成后在 Godot 编辑器中运行测试：

| Phase | 验证方法 |
|-------|----------|
| 1 | F5 运行，操作角色移动/跳跃/攻击，观察动画和碰撞 |
| 2 | 放置 3 种小怪，验证 AI 行为差异和伤害交互 |
| 3 | 击杀怪物后检查掉落物生成、拾取、背包显示 |
| 4 | 穿戴装备后检查属性面板数值变化 |
| 5 | 强化到 +5 验证属性增长，强化 +6 验证失败降级 |
| 6 | 挑战精英和 Boss，验证技能行为和掉落 |
| 7 | 完整跑图验证区域划分和刷新计时 |
| 8 | 退出重进验证存档恢复 |
