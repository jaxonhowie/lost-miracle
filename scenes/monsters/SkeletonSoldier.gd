extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	monster_id = "skeleton_soldier"
	super()
	sprite.color = Color(0.9, 0.85, 0.7, 1)
