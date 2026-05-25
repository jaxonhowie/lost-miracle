extends Node

signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_progress(quest_id: String, current: int, target: int)

var _quests: Dictionary = {}       # id -> quest data
var _active: Dictionary = {}       # id -> { progress: int }
var _completed: Array = []

func _ready():
	_load_quest_data()
	# Connect to AchievementSystem for stat-based quest tracking
	var ach_sys = get_node_or_null("/root/AchievementSystem")
	if ach_sys:
		ach_sys.stat_changed.connect(_on_stat_changed)
	# Connect to InventorySystem for collect quest tracking
	var inv_sys = get_node_or_null("/root/InventorySystem")
	if inv_sys:
		inv_sys.item_added.connect(_on_item_added)

func _load_quest_data():
	var file = FileAccess.open("res://data/quests.json", FileAccess.READ)
	if not file:
		push_error("QuestSystem: cannot open quests.json")
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("QuestSystem: JSON parse error")
		return
	for q in json.data.get("quests", []):
		_quests[q["id"]] = q

func accept_quest(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		return false
	if quest_id in _completed:
		return false
	if _active.has(quest_id):
		return false
	# Check prerequisite
	var quest = _quests[quest_id]
	var prereq = quest.get("prerequisite", "")
	if not prereq.is_empty() and not (prereq in _completed):
		return false
	_active[quest_id] = { "progress": 0 }
	quest_accepted.emit(quest_id)
	# Check initial progress
	_update_quest_progress(quest_id)
	return true

func is_available(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		return false
	if quest_id in _completed or _active.has(quest_id):
		return false
	var quest = _quests[quest_id]
	var prereq = quest.get("prerequisite", "")
	if prereq.is_empty():
		return true
	return prereq in _completed

func is_active(quest_id: String) -> bool:
	return _active.has(quest_id)

func is_completed(quest_id: String) -> bool:
	return quest_id in _completed

func get_available_quests() -> Array:
	var result = []
	for qid in _quests:
		if is_available(qid):
			result.append(_quests[qid])
	return result

func get_active_quests() -> Array:
	var result = []
	for qid in _active:
		var qdata = _quests[qid].duplicate()
		qdata["progress"] = _active[qid]["progress"]
		result.append(qdata)
	return result

func get_completed_quests() -> Array:
	var result = []
	for qid in _completed:
		if _quests.has(qid):
			result.append(_quests[qid])
	return result

func get_quest_progress(quest_id: String) -> Dictionary:
	if _active.has(quest_id):
		return _active[quest_id]
	return {}

func _on_stat_changed(key: String, _value: int):
	for qid in _active:
		var quest = _quests[qid]
		var qtype = quest.get("type", "")
		# Check if this stat change is relevant to any active quest
		match qtype:
			"kill":
				var target_id = quest.get("target_id", "")
				if key == "total_kills" or (target_id != "" and key == "kills_by_type/" + target_id):
					_update_quest_progress(qid)
			"enhance":
				if key == "max_enhance" or key == "enhance_successes":
					_update_quest_progress(qid)
			"level":
				if key == "max_level":
					_update_quest_progress(qid)
			"collect":
				pass  # handled by _on_item_added

func _on_item_added(item_id: String, _count: int):
	for qid in _active:
		var quest = _quests[qid]
		if quest.get("type", "") == "collect" and quest.get("target_id", "") == item_id:
			_update_quest_progress(qid)

func _update_quest_progress(quest_id: String):
	if not _active.has(quest_id):
		return
	var quest = _quests[quest_id]
	var qtype = quest.get("type", "")
	var target_count = quest.get("target_count", 1)
	var target_id = quest.get("target_id", "")

	var current_progress = 0
	var ach_sys = get_node_or_null("/root/AchievementSystem")

	match qtype:
		"kill":
			if ach_sys:
				if target_id.is_empty():
					current_progress = ach_sys.get_stat("total_kills")
				else:
					current_progress = ach_sys.get_nested_stat("kills_by_type/" + target_id)
		"enhance":
			if ach_sys:
				current_progress = ach_sys.get_stat("max_enhance")
		"level":
			var level_sys = get_node_or_null("/root/LevelSystem")
			if level_sys:
				current_progress = level_sys.level
		"collect":
			var inv = get_node_or_null("/root/InventorySystem")
			if inv:
				current_progress = inv.get_item_count(target_id)

	_active[quest_id]["progress"] = current_progress
	quest_progress.emit(quest_id, current_progress, target_count)

	if current_progress >= target_count:
		_complete_quest(quest_id)

func _complete_quest(quest_id: String):
	if quest_id in _completed:
		return
	_completed.append(quest_id)
	_active.erase(quest_id)

	# Award gold reward
	var quest = _quests[quest_id]
	var reward_gold = quest.get("reward_gold", 0)
	if reward_gold > 0:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			players[0].add_gold(reward_gold)

	quest_completed.emit(quest_id)

func get_save_data() -> Dictionary:
	return { "active": _active, "completed": _completed }

func load_save_data(data: Dictionary):
	_active = data.get("active", {})
	_completed = data.get("completed", [])
	# Re-check progress for all active quests
	for qid in _active:
		_update_quest_progress(qid)
