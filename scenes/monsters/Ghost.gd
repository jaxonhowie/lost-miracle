extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	monster_id = "ghost"
	hp = 60
	max_hp = 60
	attack_power = 15
	defense = 0
	move_speed = 120.0
	attack_interval = 1.4
	experience = 8
	sprite.color = Color(0.6, 0.7, 1.0, 0.7)
	# Ghost passes through platforms — no collision with environment
	collision_mask = 0
