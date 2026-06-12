class_name DungeonManager
extends RefCounted

## 地牢探索管理器 — 普通事件池 + 自动战斗精英挑战

signal event_triggered(event_type: String, event_data: Dictionary)

func explore() -> void:
	# 自动战斗：精英已刷新时概率直接挑战精英
	if Game.auto_battle and Game.is_elite_available():
		var chance = DataManager.get_elite_auto_chance()
		if randf() < chance:
			event_triggered.emit("elite_monster", _generate_event_data("elite_monster"))
			return
	var event_type = _roll_event()
	var event_data = _generate_event_data(event_type)
	event_triggered.emit(event_type, event_data)

func _roll_event() -> String:
	var events = DataManager.get_event_probabilities()
	var roll = randf()
	var cumulative = 0.0
	for event_type in events:
		cumulative += events[event_type].get("probability", 0)
		if roll < cumulative:
			return event_type
	return "normal_monster"

func _generate_event_data(event_type: String) -> Dictionary:
	match event_type:
		"normal_monster":
			return {"monster_id": DataManager.pick_random_monster_id("normal", "", "rotting_skeleton")}
		"elite_monster":
			return {"monster_id": DataManager.pick_random_monster_id("elite", "", "bone_guardian")}
		"chest":
			var gold := 0
			var stone := 0
			if Game.current_dungeon_id == "corrupt_swamp":
				var chest_cfg = DataManager.get_jewelry_config().get("corrupt_swamp_drops", {}).get("chest_bonus", {})
				gold = randi_range(int(chest_cfg.get("gold_min", 80)), int(chest_cfg.get("gold_max", 180)))
			elif Game.current_dungeon_id == "frozen_abyss":
				var chest_cfg = DataManager.get_jewelry_config().get("frozen_abyss_drops", {}).get("chest_bonus", {})
				gold = randi_range(int(chest_cfg.get("gold_min", 120)), int(chest_cfg.get("gold_max", 260)))
			elif Game.current_dungeon_id == "forge_ruins":
				var chest_cfg = DataManager.get_jewelry_config().get("forge_ruins_drops", {}).get("chest_bonus", {})
				gold = randi_range(int(chest_cfg.get("gold_min", 100)), int(chest_cfg.get("gold_max", 220)))
			else:
				gold = randi_range(50, 150)
				stone = randi_range(1, 3) if randf() < 0.5 else 0
			var data := {"gold": gold, "enhance_stone": stone}
			if Game.current_dungeon_id == "forge_ruins":
				var bonus = DataManager.get_jewelry_config().get("chest_bonus", {}).get("forge_ruins", {})
				var jewelry_stone = randi_range(int(bonus.get("jewelry_min", 0)), int(bonus.get("jewelry_max", 0)))
				if jewelry_stone > 0:
					data["jewelry_enhance_stone"] = jewelry_stone
				if randf() < float(bonus.get("blessed_jewelry_chance", 0.0)):
					var blessed = randi_range(int(bonus.get("blessed_jewelry_min", 0)), int(bonus.get("blessed_jewelry_max", 0)))
					if blessed > 0:
						data["blessed_jewelry_enhance_stone"] = blessed
			elif Game.current_dungeon_id == "corrupt_swamp":
				var ring = LootManager.roll_chest_ring()
				if not ring.is_empty():
					data["ring"] = ring
			elif Game.current_dungeon_id == "frozen_abyss":
				var necklace = LootManager.roll_chest_necklace()
				if not necklace.is_empty():
					data["necklace"] = necklace
			return data
		"altar":
			var buff_type = ["atk", "def", "max_hp"][randi() % 3]
			return {"buff_type": buff_type, "buff_value": 0.15, "duration": 5}
		"trap":
			var damage = randi_range(30, 80)
			return {"damage": damage}
		_:
			return {}
