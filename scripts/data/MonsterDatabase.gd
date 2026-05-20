extends Node

var _data: Dictionary = {}

func _ready():
	var file = FileAccess.open("res://data/monsters.json", FileAccess.READ)
	if not file:
		push_error("MonsterDatabase: cannot open monsters.json")
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("MonsterDatabase: JSON parse error")
		return
	_data = json.data

func get_monster(monster_id: String) -> Dictionary:
	return _data.get(monster_id, {})

func get_stat(monster_id: String, stat: String, default_value = 0):
	var m = get_monster(monster_id)
	return m.get(stat, default_value)
