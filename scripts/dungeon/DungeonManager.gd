class_name DungeonManager
extends RefCounted

## 地牢探索管理器 — 事件池随机

signal event_triggered(event_type: String, event_data: Dictionary)

var explore_count: int = 0

func explore() -> void:
	explore_count += 1
	var event_type = _roll_event()
	var event_data = _generate_event_data(event_type)
	event_triggered.emit(event_type, event_data)

func _roll_event() -> String:
	# Boss 入口优先检查
	if Game.can_challenge_boss():
		if randf() < 0.05:
			return "boss_entrance"
	# 普通事件池
	var events = DataManager.get_event_probabilities()
	var roll = randf()
	var cumulative = 0.0
	for event_type in events:
		cumulative += events[event_type].get("probability", 0)
		if roll < cumulative:
			# Boss 入口需要满足条件
			if event_type == "boss_entrance" and not Game.can_challenge_boss():
				return "normal_monster"
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
			var monsters = DataManager.get_monsters_by_type("elite")
			if monsters.is_empty():
				return {"monster_id": "bone_guardian"}
			var m = monsters[randi() % monsters.size()]
			return {"monster_id": m.get("id", "bone_guardian")}
		"boss_entrance":
			var monsters = DataManager.get_monsters_by_type("boss")
			if monsters.is_empty():
				return {"monster_id": "dungeon_lord_morgan"}
			return {"monster_id": monsters[0].get("id", "dungeon_lord_morgan")}
		"chest":
			var gold = randi_range(30, 100)
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
