extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	monster_id = "crystal_golem"
	super()
	sprite.color = Color(0.4, 0.7, 0.9, 1)
	sprite.size = Vector2(48, 48)
