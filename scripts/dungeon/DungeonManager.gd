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
			var monsters = DataManager.get_monsters_by_type("normal")
			if monsters.is_empty():
				return {"monster_id": "rotting_skeleton"}
			var m = monsters[randi() % monsters.size()]
			return {"monster_id": m.get("id", "rotting_skeleton")}
		"elite_monster":
			var elites = DataManager.get_monsters_by_type("elite")
			if elites.is_empty():
				return {"monster_id": "bone_guardian"}
			var e = elites[randi() % elites.size()]
			return {"monster_id": e.get("id", "bone_guardian")}
		"chest":
			var gold = randi_range(50, 150)
			var stone = randi_range(1, 3) if randf() < 0.5 else 0
			return {"gold": gold, "enhance_stone": stone}
		"altar":
			var buff_type = ["atk", "def", "max_hp"][randi() % 3]
			return {"buff_type": buff_type, "buff_value": 0.15, "duration": 5}
		"trap":
			var damage = randi_range(30, 80)
			return {"damage": damage}
		_:
			return {}
