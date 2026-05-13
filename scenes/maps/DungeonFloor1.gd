extends Node2D

const SPAWN_DATA_PATH = "res://data/spawns_dungeon_1.json"

func _ready():
	_register_spawns()

func _register_spawns():
	var file = FileAccess.open(SPAWN_DATA_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	if not json.data is Array:
		return
	for entry in json.data:
		SpawnSystem.register_spawn_point(entry)
