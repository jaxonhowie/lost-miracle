extends Node

signal item_dropped(item_id: String, count: int, position: Vector2)

var drop_item_scene: PackedScene

func _ready():
	drop_item_scene = preload("res://scenes/items/DropItem.tscn")

func on_monster_died(monster_id: String, death_position: Vector2):
	var drops = DropTableDatabase.roll_drops(monster_id)
	# Talent bonus: luck tree boosts drop rate and gold
	var talent_sys = get_node_or_null("/root/TalentSystem")
	var drop_rate_bonus: float = 0.0
	var gold_bonus_mult: float = 1.0
	if talent_sys:
		drop_rate_bonus = talent_sys.get_bonus("drop_rate")
		gold_bonus_mult += talent_sys.get_bonus("gold_bonus")
	# Apply drop_rate bonus as multiplier on existing drop rates
	if drop_rate_bonus > 0:
		var bonus_drops = DropTableDatabase.roll_drops(monster_id)
		for drop in bonus_drops:
			if randf() < drop_rate_bonus:
				drops.append(drop)
	for drop in drops:
		if drop["item_id"] == "gold":
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				players[0].add_gold(int(drop["count"] * gold_bonus_mult))
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

func spawn_drop(item_id: String, position: Vector2, count: int = 1):
	_spawn_drop_item(item_id, count, position)

func get_drops_for_monster(monster_id: String) -> Array:
	return DropTableDatabase.roll_drops(monster_id)
