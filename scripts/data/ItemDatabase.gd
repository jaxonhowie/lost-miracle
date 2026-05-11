extends Node

var items: Dictionary = {}

func _ready():
	_load_items()

func _load_items():
	var file = FileAccess.open("res://data/items.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		json.parse(file.get_as_text())
		items = json.data
		file.close()

func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})

func get_item_name(item_id: String) -> String:
	var item = get_item(item_id)
	return item.get("name", item_id)

func is_equipment(item_id: String) -> bool:
	return get_item(item_id).get("type", "") == "equipment"

func is_material(item_id: String) -> bool:
	var t = get_item(item_id).get("type", "")
	return t == "material" or t == "currency"

func get_quality_color(quality: String) -> Color:
	match quality:
		"normal":
			return Color.WHITE
		"fine":
			return Color.GREEN
		"rare":
			return Color.CYAN
		"epic":
			return Color(0.6, 0.2, 0.9, 1)
		_:
			return Color.WHITE
