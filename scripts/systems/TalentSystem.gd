extends Node

signal talent_learned(talent_id: String, new_rank: int)
signal talent_points_changed(new_total: int)

var talent_points: int = 0
var _ranks: Dictionary = {}        # talent_id -> current rank
var _categories: Array = []
var _talent_index: Dictionary = {}  # talent_id -> talent definition
var _respec_cost: int = 500

func _ready():
	_load_talent_data()

func _load_talent_data():
	var file = FileAccess.open("res://data/talents.json", FileAccess.READ)
	if not file:
		push_error("TalentSystem: cannot open talents.json")
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("TalentSystem: JSON parse error")
		return
	_categories = json.data.get("categories", [])
	_respec_cost = json.data.get("respec_gold_cost", 500)
	for cat in _categories:
		for talent in cat["talents"]:
			_talent_index[talent["id"]] = talent

func add_talent_points(amount: int):
	talent_points += amount
	talent_points_changed.emit(talent_points)

func can_learn(talent_id: String) -> bool:
	if not _talent_index.has(talent_id):
		return false
	if talent_points <= 0:
		return false
	var current = _ranks.get(talent_id, 0)
	var max_r = _talent_index[talent_id].get("max_rank", 1)
	return current < max_r

func learn_talent(talent_id: String) -> bool:
	if not can_learn(talent_id):
		return false
	var current = _ranks.get(talent_id, 0)
	_ranks[talent_id] = current + 1
	talent_points -= 1
	talent_learned.emit(talent_id, current + 1)
	talent_points_changed.emit(talent_points)
	return true

func get_bonus(key: String) -> float:
	var total: float = 0.0
	for talent_id in _talent_index:
		var talent = _talent_index[talent_id]
		if talent.get("stat_key", "") == key:
			var rank = _ranks.get(talent_id, 0)
			total += talent.get("bonus_per_rank", 0.0) * rank
	return total

func get_talent_info(talent_id: String) -> Dictionary:
	if not _talent_index.has(talent_id):
		return {}
	var talent = _talent_index[talent_id].duplicate()
	var current = _ranks.get(talent_id, 0)
	talent["current_rank"] = current
	talent["total_bonus"] = talent.get("bonus_per_rank", 0.0) * current
	talent["can_learn"] = can_learn(talent_id)
	return talent

func get_category_talents(category_id: String) -> Array:
	for cat in _categories:
		if cat["id"] == category_id:
			var result = []
			for talent in cat["talents"]:
				result.append(get_talent_info(talent["id"]))
			return result
	return []

func get_categories() -> Array:
	return _categories

func can_respec() -> bool:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	return players[0].gold >= _respec_cost

func respec() -> bool:
	if not can_respec():
		return false
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	# Count total spent points
	var total_spent = 0
	for rank in _ranks.values():
		total_spent += rank
	# Deduct gold
	players[0].gold -= _respec_cost
	# Reset ranks and refund points
	_ranks.clear()
	talent_points += total_spent
	talent_points_changed.emit(talent_points)
	return true

func get_save_data() -> Dictionary:
	return { "talent_points": talent_points, "ranks": _ranks.duplicate() }

func load_save_data(data: Dictionary):
	talent_points = data.get("talent_points", 0)
	_ranks = data.get("ranks", {})
