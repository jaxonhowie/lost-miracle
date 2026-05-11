extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	monster_id = "skeleton_soldier"
	hp = 60
	max_hp = 60
	attack_power = 8
	defense = 1
	move_speed = 80.0
	attack_interval = 1.2
	experience = 5
	sprite.color = Color(0.9, 0.85, 0.7, 1)
