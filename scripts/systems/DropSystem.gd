extends Node

signal item_dropped(item_id: String, count: int, position: Vector2)

var drop_item_scene: PackedScene

func _ready():
	drop_item_scene = preload("res://scenes/items/DropItem.tscn")

func on_monster_died(monster_id: String, death_position: Vector2):
	var drops = DropTableDatabase.roll_drops(monster_id)
	for drop in drops:
		if drop["item_id"] == "gold":
			# Gold goes directly to player
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				players[0].add_gold(drop["count"])
			item_dropped.emit("gold", drop["count"], death_position)
		else:
			_spawn_drop_item(drop["item_id"], drop["count"], death_position)

func _spawn_drop_item(item_id: String, count: int, position: Vector2):
	var drop_item = drop_item_scene.instantiate()
	drop_item.global_position = position
	drop_item.setup(item_id, count)
	get_tree().current_scene.add_child(drop_item)
	# Pop animation
	var target_x = position.x + randf_range(-40, 40)
	var target_y = position.y - randf_range(30, 80)
	drop_item.pop_toward(Vector2(target_x, target_y))
	item_dropped.emit(item_id, count, position)
