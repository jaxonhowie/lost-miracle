extends Node

## 数据管理 — 加载所有 JSON 配置

var monsters: Dictionary = {}
var skills: Dictionary = {}
var equipment_base: Dictionary = {}
var sets: Dictionary = {}
var dungeon_events: Dictionary = {}
var affixes: Array = []
var equipment_grades: Dictionary = {}
var enhance_rules: Dictionary = {}

func _ready() -> void:
	monsters = _load_json("res://data/monsters.json")
	skills = _load_json("res://data/skills.json")
	equipment_base = _load_json("res://data/equipment_base.json")
	sets = _load_json("res://data/sets.json")
	dungeon_events = _load_json("res://data/dungeon_events.json")
	var affix_data = _load_json("res://data/affixes.json")
	affixes = affix_data.get("affixes", []) if affix_data is Dictionary else []
	equipment_grades = _load_json("res://data/equipment_grades.json")
	enhance_rules = _load_json("res://data/enhance_rules.json")

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("DataManager: file not found: " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("DataManager: JSON parse error in " + path)
		return {}
	return json.data

# --- 查询接口 ---

func get_monster(monster_id: String) -> Dictionary:
	return monsters.get(monster_id, {})

func get_monsters_by_type(type: String) -> Array:
	var result := []
	for id in monsters:
		if monsters[id].get("type", "") == type:
			result.append(monsters[id])
	return result

func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})

func get_equipment_base(base_id: String) -> Dictionary:
	return equipment_base.get(base_id, {})

func get_all_equipment_bases() -> Array:
	var result := []
	for id in equipment_base:
		result.append(equipment_base[id])
	return result

func get_set(set_id: String) -> Dictionary:
	return sets.get(set_id, {})

func get_event_probabilities() -> Dictionary:
	return dungeon_events.get("events", {})

func get_elite_auto_chance() -> float:
	return float(dungeon_events.get("elite_auto_challenge_chance", 0.25))

func get_affixes() -> Array:
	return affixes

func get_grade(grade_id: String) -> Dictionary:
	return equipment_grades.get(grade_id, {})

func get_enhance_rules() -> Dictionary:
	return enhance_rules
