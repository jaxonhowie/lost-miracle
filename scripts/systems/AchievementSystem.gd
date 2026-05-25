extends Node

signal achievement_unlocked(achievement_id: String)
signal stat_changed(key: String, value: int)

var _achievements: Dictionary = {}  # id -> achievement data
var _stats: Dictionary = {}         # key -> int value
var _unlocked: Array = []           # achievement ids
var _check_pending: bool = false

func _ready():
	_load_achievement_data()

func _process(_delta):
	if _check_pending:
		_check_pending = false
		_check_achievements()

func _load_achievement_data():
	var file = FileAccess.open("res://data/achievements.json", FileAccess.READ)
	if not file:
		push_error("AchievementSystem: cannot open achievements.json")
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("AchievementSystem: JSON parse error")
		return
	for ach in json.data.get("achievements", []):
		_achievements[ach["id"]] = ach

func track_stat(key: String, value: int = 1):
	# Support nested paths like "kills_by_type/skeleton_soldier"
	if "/" in key:
		var parts = key.split("/")
		var category = parts[0]
		var subkey = parts[1]
		if not _stats.has(category):
			_stats[category] = {}
		if not _stats[category] is Dictionary:
			_stats[category] = {}
		var current = _stats[category].get(subkey, 0)
		_stats[category][subkey] = current + value
		stat_changed.emit(key, _stats[category][subkey])
	else:
		var current = _stats.get(key, 0)
		_stats[key] = current + value
		stat_changed.emit(key, _stats[key])
	_check_pending = true

func set_stat(key: String, value: int):
	if "/" in key:
		var parts = key.split("/")
		var category = parts[0]
		var subkey = parts[1]
		if not _stats.has(category):
			_stats[category] = {}
		if not _stats[category] is Dictionary:
			_stats[category] = {}
		_stats[category][subkey] = value
		stat_changed.emit(key, value)
	else:
		_stats[key] = value
		stat_changed.emit(key, value)
	_check_pending = true

func get_stat(key: String) -> int:
	return _stats.get(key, 0)

func get_nested_stat(key: String) -> int:
	if "/" in key:
		var parts = key.split("/")
		var category = parts[0]
		var subkey = parts[1]
		if _stats.has(category) and _stats[category] is Dictionary:
			return _stats[category].get(subkey, 0)
	return _stats.get(key, 0)

func _check_achievements():
	for ach_id in _achievements:
		if ach_id in _unlocked:
			continue
		var ach = _achievements[ach_id]
		var condition = ach.get("condition", "")
		if _evaluate_condition(condition):
			_unlocked.append(ach_id)
			var reward = ach.get("reward_gold", 0)
			if reward > 0:
				var players = get_tree().get_nodes_in_group("player")
				if not players.is_empty():
					players[0].add_gold(reward)
			achievement_unlocked.emit(ach_id)

func _evaluate_condition(condition: String) -> bool:
	if condition.is_empty():
		return false
	# Parse "key >= value" or "key == value"
	var op: String = ""
	var parts: PackedStringArray = []
	if ">=" in condition:
		parts = condition.split(">=")
		op = ">="
	elif "==" in condition:
		parts = condition.split("==")
		op = "=="
	else:
		return false

	var key = parts[0].strip_edges()
	var target = parts[1].strip_edges().to_int()

	# Support nested stat lookup
	var current: int = 0
	if "/" in key:
		var path_parts = key.split("/")
		var category = path_parts[0]
		var subkey = path_parts[1]
		if _stats.has(category) and _stats[category] is Dictionary:
			current = _stats[category].get(subkey, 0)
	else:
		current = _stats.get(key, 0)

	match op:
		">=":
			return current >= target
		"==":
			return current == target
	return false

func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in _unlocked

func get_all() -> Array:
	return _achievements.values()

func get_unlocked_ids() -> Array:
	return _unlocked.duplicate()

func get_save_data() -> Dictionary:
	return { "stats": _stats, "unlocked": _unlocked }

func load_save_data(data: Dictionary):
	_stats = data.get("stats", {})
	_unlocked = data.get("unlocked", [])
