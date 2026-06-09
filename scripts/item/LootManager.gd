class_name LootManager
extends RefCounted

## 掉落管理器

## 怪物类型 -> 掉落数量范围
const DROP_COUNT = {
	"normal": {"min": 0, "max": 1},
	"elite": {"min": 1, "max": 2},
	"boss": {"min": 2, "max": 3},
}

## 怪物类型 -> 掉落金币范围
const GOLD_DROP = {
	"normal": {"min": 5, "max": 20},
	"elite": {"min": 30, "max": 80},
	"boss": {"min": 100, "max": 300},
}

## 怪物类型 -> 强化石掉落
const STONE_DROP = {
	"normal": {"min": 0, "max": 1, "rate": 0.3},
	"elite": {"min": 1, "max": 2, "rate": 0.7},
	"boss": {"min": 2, "max": 5, "rate": 1.0},
}

static func roll_drops(monster_id: String) -> Array:
	var monster_data = DataManager.get_monster(monster_id)
	var monster_type = monster_data.get("type", "normal")
	var drops := []
	# 装备掉落
	var count_range = DROP_COUNT.get(monster_type, DROP_COUNT["normal"])
	var drop_count = randi_range(count_range["min"], count_range["max"])
	for i in drop_count:
		var eq = Equipment.generate_equipment(monster_type)
		if not eq.is_empty():
			drops.append(eq)
	# 金币
	var gold_range = GOLD_DROP.get(monster_type, GOLD_DROP["normal"])
	var gold = randi_range(gold_range["min"], gold_range["max"])
	drops.append({"type": "gold", "amount": gold})
	# 强化石
	var stone_info = STONE_DROP.get(monster_type, STONE_DROP["normal"])
	if randf() <= stone_info["rate"]:
		var stone_count = randi_range(stone_info["min"], stone_info["max"])
		drops.append({"type": "enhance_stone", "amount": stone_count})
	return drops
