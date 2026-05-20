extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	monster_id = "ghost"
	super()
	sprite.color = Color(0.6, 0.7, 1.0, 0.7)
	collision_mask = 0
