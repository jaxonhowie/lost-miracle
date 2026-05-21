extends Node

var drop_tables: Dictionary = {}

func _ready():
	_load_drops()

func _load_drops():
	var file = FileAccess.open("res://data/drops.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		json.parse(file.get_as_text())
		drop_tables = json.data
		file.close()

func get_drops(monster_id: String) -> Array:
	return drop_tables.get(monster_id, [])

func roll_drops(monster_id: String) -> Array:
	var results = []
	var table = get_drops(monster_id)
	var bonus: float = 0.0
	var diff_sys = get_node_or_null("/root/DifficultySystem")
	if diff_sys:
		bonus = diff_sys.get_drop_bonus()
	for entry in table:
		var rate = minf(entry["rate"] + bonus, 1.0)
		if randf() <= rate:
			var count = randi_range(entry["min"], entry["max"])
			results.append({"item_id": entry["item_id"], "count": count})
	return results
