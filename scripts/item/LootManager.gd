class_name LootManager
extends RefCounted

## 掉落管理器

## 怪物类型 -> 装备掉率和数量范围
const EQUIP_DROP = {
	"normal": {"rate": 0.30, "min": 1, "max": 1},
	"elite": {"rate": 0.60, "min": 1, "max": 2},
	"boss": {"rate": 1.0, "min": 2, "max": 3},
}

## 怪物类型 -> 掉落金币范围
const GOLD_DROP = {
	"normal": {"min": 10, "max": 30},
	"elite": {"min": 30, "max": 80},
	"boss": {"min": 100, "max": 300},
}

## 怪物类型 -> 强化石掉落
const STONE_DROP = {
	"normal": {"min": 0, "max": 1, "rate": 0.10},
	"elite": {"min": 1, "max": 2, "rate": 0.25},
	"boss": {"min": 2, "max": 5, "rate": 0.50},
}

static func roll_drops(monster_id: String) -> Array:
	var monster_data = DataManager.get_monster(monster_id)
	var monster_type = monster_data.get("type", "normal")
	var drops := []
	# 装备掉落（概率判定）
	var equip_info = EQUIP_DROP.get(monster_type, EQUIP_DROP["normal"])
	if randf() <= equip_info["rate"]:
		var drop_count = randi_range(equip_info["min"], equip_info["max"])
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
		if stone_count > 0:
			drops.append({"type": "enhance_stone", "amount": stone_count})
	# 新手生命药水（50% 概率，1~5 瓶）
	if randf() <= 0.5:
		var potion_count = randi_range(1, 5)
		drops.append({"type": "health_potion", "amount": potion_count})
	return drops
