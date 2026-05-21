extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	monster_id = "dark_assassin"
	super()
	sprite.color = Color(0.2, 0.15, 0.3, 1)
	sprite.size = Vector2(32, 40)
