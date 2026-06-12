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

## 怪物类型 -> 强化石掉落（非锻造厂地牢）
const STONE_DROP = {
	"normal": {"min": 0, "max": 1, "rate": 0.10},
	"elite": {"min": 1, "max": 2, "rate": 0.25},
	"boss": {"min": 2, "max": 5, "rate": 0.50},
}

static func roll_drops(monster_id: String) -> Array:
	var monster_data = DataManager.get_monster(monster_id)
	var monster_type = monster_data.get("type", "normal")
	var dungeon_id = Game.current_dungeon_id
	var drops := []

	if dungeon_id == "corrupt_swamp":
		_roll_corrupt_swamp_drops(drops, monster_type)
	elif dungeon_id == "frozen_abyss":
		_roll_frozen_abyss_drops(drops, monster_type)
	else:
		var equip_info = EQUIP_DROP.get(monster_type, EQUIP_DROP["normal"])
		if randf() <= equip_info["rate"]:
			var drop_count = randi_range(equip_info["min"], equip_info["max"])
			for i in drop_count:
				var eq = Equipment.generate_equipment(monster_type)
				if not eq.is_empty():
					drops.append(eq)

		var gold_range = GOLD_DROP.get(monster_type, GOLD_DROP["normal"])
		if dungeon_id == "forge_ruins":
			var forge_gold: Dictionary = DataManager.get_jewelry_config().get("forge_ruins_drops", {}).get("gold", {}).get(monster_type, {})
			if not forge_gold.is_empty():
				gold_range = forge_gold
		drops.append({"type": "gold", "amount": randi_range(int(gold_range["min"]), int(gold_range["max"]))})

		if dungeon_id == "forge_ruins":
			_roll_forge_ruins_stones(drops, monster_type)
		else:
			var stone_info = STONE_DROP.get(monster_type, STONE_DROP["normal"])
			if randf() <= stone_info["rate"]:
				var stone_count = randi_range(stone_info["min"], stone_info["max"])
				if stone_count > 0:
					drops.append({"type": "enhance_stone", "amount": stone_count})

	if randf() <= 0.5:
		drops.append({"type": "health_potion", "amount": randi_range(1, 5)})
	return drops

static func _roll_corrupt_swamp_drops(drops: Array, monster_type: String) -> void:
	var cfg = DataManager.get_jewelry_config().get("corrupt_swamp_drops", {})
	var ring_rates: Dictionary = cfg.get("ring_drop_rates", {})
	var ring_rate = float(ring_rates.get(monster_type, ring_rates.get("normal", 0.08)))

	if monster_type == "boss":
		var guaranteed = int(cfg.get("boss_guaranteed_rings", 1))
		for i in guaranteed:
			var ring = Equipment.generate_jewelry()
			if not ring.is_empty():
				drops.append(ring)
		if randf() <= float(cfg.get("boss_extra_ring_chance", 0.35)):
			var extra = Equipment.generate_jewelry()
			if not extra.is_empty():
				drops.append(extra)
	elif randf() <= ring_rate:
		var ring = Equipment.generate_jewelry()
		if not ring.is_empty():
			drops.append(ring)

	var gold_cfg: Dictionary = cfg.get("gold", {}).get(monster_type, GOLD_DROP.get(monster_type, GOLD_DROP["normal"]))
	drops.append({"type": "gold", "amount": randi_range(int(gold_cfg.get("min", 10)), int(gold_cfg.get("max", 30)))})

	var stone_cfg: Dictionary = cfg.get("enhance_stone", {}).get(monster_type, {})
	if not stone_cfg.is_empty() and randf() <= float(stone_cfg.get("rate", 0.0)):
		var stone_count = randi_range(int(stone_cfg.get("min", 0)), int(stone_cfg.get("max", 0)))
		if stone_count > 0:
			drops.append({"type": "enhance_stone", "amount": stone_count})

static func _roll_frozen_abyss_drops(drops: Array, monster_type: String) -> void:
	var cfg = DataManager.get_jewelry_config().get("frozen_abyss_drops", {})
	var necklace_rates: Dictionary = cfg.get("necklace_drop_rates", {})
	var necklace_rate = float(necklace_rates.get(monster_type, necklace_rates.get("normal", 0.08)))

	if monster_type == "boss":
		var guaranteed = int(cfg.get("boss_guaranteed_necklaces", 1))
		for i in guaranteed:
			var necklace = Equipment.generate_necklace()
			if not necklace.is_empty():
				drops.append(necklace)
		if randf() <= float(cfg.get("boss_extra_necklace_chance", 0.35)):
			var extra = Equipment.generate_necklace()
			if not extra.is_empty():
				drops.append(extra)
	elif randf() <= necklace_rate:
		var necklace = Equipment.generate_necklace()
		if not necklace.is_empty():
			drops.append(necklace)

	var gold_cfg: Dictionary = cfg.get("gold", {}).get(monster_type, GOLD_DROP.get(monster_type, GOLD_DROP["normal"]))
	drops.append({"type": "gold", "amount": randi_range(int(gold_cfg.get("min", 10)), int(gold_cfg.get("max", 30)))})

	var stone_cfg: Dictionary = cfg.get("enhance_stone", {}).get(monster_type, {})
	if not stone_cfg.is_empty() and randf() <= float(stone_cfg.get("rate", 0.0)):
		var stone_count = randi_range(int(stone_cfg.get("min", 0)), int(stone_cfg.get("max", 0)))
		if stone_count > 0:
			drops.append({"type": "enhance_stone", "amount": stone_count})

static func roll_chest_ring() -> Dictionary:
	if Game.current_dungeon_id != "corrupt_swamp":
		return {}
	var cfg = DataManager.get_jewelry_config().get("corrupt_swamp_drops", {}).get("chest_bonus", {})
	if randf() > float(cfg.get("ring_chance", 0.0)):
		return {}
	var ring = Equipment.generate_jewelry()
	if ring.is_empty():
		return {}
	return ring

static func roll_chest_necklace() -> Dictionary:
	if Game.current_dungeon_id != "frozen_abyss":
		return {}
	var cfg = DataManager.get_jewelry_config().get("frozen_abyss_drops", {}).get("chest_bonus", {})
	if randf() > float(cfg.get("necklace_chance", 0.0)):
		return {}
	var necklace = Equipment.generate_necklace()
	if necklace.is_empty():
		return {}
	return necklace

static func _roll_forge_ruins_stones(drops: Array, monster_type: String) -> void:
	var cfg = DataManager.get_jewelry_config().get("jewelry_stone_drop", {}).get("forge_ruins", {})
	var stone_info: Dictionary = cfg.get(monster_type, cfg.get("normal", {}))
	if stone_info.is_empty():
		return
	if randf() <= float(stone_info.get("jewelry_rate", 0.0)):
		var count = randi_range(int(stone_info.get("jewelry_min", 0)), int(stone_info.get("jewelry_max", 0)))
		if count > 0:
			drops.append({"type": "jewelry_enhance_stone", "amount": count})
	if randf() <= float(stone_info.get("blessed_jewelry_rate", 0.0)):
		var blessed_count = randi_range(int(stone_info.get("blessed_jewelry_min", 0)), int(stone_info.get("blessed_jewelry_max", 0)))
		if blessed_count > 0:
			drops.append({"type": "blessed_jewelry_enhance_stone", "amount": blessed_count})
	if randf() <= float(stone_info.get("enhance_rate", 0.0)):
		var enhance_count = randi_range(int(stone_info.get("enhance_min", 0)), int(stone_info.get("enhance_max", 0)))
		if enhance_count > 0:
			drops.append({"type": "enhance_stone", "amount": enhance_count})
