extends Node

signal skill_unlocked(skill_id: String)
signal skill_points_changed(points: int)

var skill_points: int = 0
var unlocked_skills: Array = []
var _skill_data: Dictionary = {}

func _ready():
	_load_skill_data()
	# Connect to level system for skill points
	var level_sys = get_node_or_null("/root/LevelSystem")
	if level_sys:
		level_sys.leveled_up.connect(_on_leveled_up)

func _load_skill_data():
	var file = FileAccess.open("res://data/skills.json", FileAccess.READ)
	if file:
		_skill_data = JSON.parse_string(file.get_as_text())
		file.close()

func _on_leveled_up(_new_level: int):
	skill_points += 1
	skill_points_changed.emit(skill_points)

func add_skill_points(amount: int):
	skill_points += amount
	skill_points_changed.emit(skill_points)

func can_unlock_skill(skill_id: String, class_id: String, level: int) -> bool:
	if skill_points <= 0:
		return false
	if skill_id in unlocked_skills:
		return false
	var data = _skill_data.get(skill_id, {})
	if data.is_empty():
		return false
	if data.get("class", "") != class_id:
		return false
	if data.get("unlock_level", 99) > level:
		return false
	return true

func unlock_skill(skill_id: String, class_id: String, level: int) -> bool:
	if not can_unlock_skill(skill_id, class_id, level):
		return false
	skill_points -= 1
	unlocked_skills.append(skill_id)
	skill_unlocked.emit(skill_id)
	skill_points_changed.emit(skill_points)
	return true

func is_unlocked(skill_id: String) -> bool:
	return skill_id in unlocked_skills

func get_available_skills(class_id: String, level: int) -> Array:
	var available = []
	for skill_id in _skill_data:
		var data = _skill_data[skill_id]
		if data.get("class", "") == class_id and data.get("unlock_level", 99) <= level:
			available.append(skill_id)
	return available

func get_skill_data(skill_id: String) -> Dictionary:
	return _skill_data.get(skill_id, {})

func get_class_skills(class_id: String) -> Array:
	var skills = []
	for skill_id in _skill_data:
		if _skill_data[skill_id].get("class", "") == class_id:
			skills.append(skill_id)
	return skills

func get_save_data() -> Dictionary:
	return {
		"skill_points": skill_points,
		"unlocked_skills": unlocked_skills,
	}

func load_save_data(data: Dictionary):
	skill_points = data.get("skill_points", 0)
	unlocked_skills = data.get("unlocked_skills", [])
	skill_points_changed.emit(skill_points)
