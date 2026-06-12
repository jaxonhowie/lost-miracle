extends Node

## 数据管理 — 加载所有 JSON 配置

var monsters: Dictionary = {}
var skills: Dictionary = {}
var equipment_base: Dictionary = {}
var sets: Dictionary = {}
var dungeon_events: Dictionary = {}
var enhance_rules: Dictionary = {}
var jewelry: Dictionary = {}

func _ready() -> void:
	monsters = _load_json("res://data/monsters.json")
	skills = _load_json("res://data/skills.json")
	equipment_base = _load_json("res://data/equipment_base.json")
	sets = _load_json("res://data/sets.json")
	dungeon_events = _load_json("res://data/dungeon_events.json")
	enhance_rules = _load_json("res://data/enhance_rules.json")
	jewelry = _load_json("res://data/jewelry.json")

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

func get_monsters_by_type(type: String, dungeon_id: String = "") -> Array:
	var did = dungeon_id if not dungeon_id.is_empty() else Game.current_dungeon_id
	var result := []
	for id in monsters:
		var m = monsters[id]
		if m.get("type", "") != type:
			continue
		var dungeons: Array = m.get("dungeons", ["bone_crypt"])
		if did in dungeons:
			result.append(m)
	return result

func pick_random_monster_id(type: String, dungeon_id: String = "", fallback_id: String = "") -> String:
	var pool = get_monsters_by_type(type, dungeon_id)
	if pool.is_empty():
		return fallback_id
	return pool[randi() % pool.size()].get("id", fallback_id)

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

func get_enhance_rules() -> Dictionary:
	return enhance_rules

func get_jewelry_config() -> Dictionary:
	return jewelry

func get_jewelry_lines() -> Dictionary:
	return jewelry.get("lines", {})

func get_jewelry_line(line_id: String) -> Dictionary:
	return get_jewelry_lines().get(line_id, {})

func get_jewelry_stats(line_id: String, level: int) -> Dictionary:
	var line = get_jewelry_line(line_id)
	var tiers: Array = line.get("stats_by_level", [])
	if level < 0 or level >= tiers.size():
		return {}
	return tiers[level].duplicate()

func get_jewelry_name(line_id: String, level: int) -> String:
	var line = get_jewelry_line(line_id)
	var names: Array = line.get("names", [])
	if level < 0 or level >= names.size():
		return line.get("id", "戒指")
	return str(names[level])

func get_necklace_lines() -> Dictionary:
	return jewelry.get("necklace_lines", {})

func get_necklace_line(line_id: String) -> Dictionary:
	return get_necklace_lines().get(line_id, {})

func get_necklace_stats(line_id: String, level: int) -> Dictionary:
	var line = get_necklace_line(line_id)
	var tiers: Array = line.get("stats_by_level", [])
	if level < 0 or level >= tiers.size():
		return {}
	return tiers[level].duplicate()

func get_necklace_name(line_id: String, level: int) -> String:
	var line = get_necklace_line(line_id)
	var names: Array = line.get("names", [])
	if level < 0 or level >= names.size():
		return line.get("id", "项链")
	return str(names[level])

func get_jewelry_resonance(line_a: String, line_b: String) -> Dictionary:
	if line_a == line_b:
		return {}
	var key = line_a + "_" + line_b if line_a < line_b else line_b + "_" + line_a
	return jewelry.get("resonance", {}).get(key, {})
