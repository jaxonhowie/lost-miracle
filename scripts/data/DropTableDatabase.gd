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
	for entry in table:
		if randf() <= entry["rate"]:
			var count = randi_range(entry["min"], entry["max"])
			results.append({"item_id": entry["item_id"], "count": count})
	return results
