extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	hp = 45
	max_hp = 45
	attack_power = 12
	defense = 0
	move_speed = 120.0
	attack_interval = 1.4
	experience = 8
	sprite.color = Color(0.6, 0.7, 1.0, 0.7)
	# Ghost passes through platforms — no collision with environment
	collision_mask = 0
