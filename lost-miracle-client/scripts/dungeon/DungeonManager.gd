class_name DungeonManager
extends RefCounted

## 地牢探索管理器 — 事件池 + 服务端刷怪槽

signal event_triggered(event_type: String, event_data: Dictionary)

func roll_event_type() -> String:
	return _roll_event()

func explore() -> void:
	event_triggered.emit(roll_event_type(), {})

func generate_event_data(event_type: String) -> Dictionary:
	return _generate_event_data(event_type)

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
