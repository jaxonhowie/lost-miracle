extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	monster_id = "wraith"
	super()
	sprite.color = Color(0.6, 0.5, 0.8, 0.7)
	sprite.size = Vector2(36, 44)
