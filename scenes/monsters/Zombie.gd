extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	hp = 100
	max_hp = 100
	attack_power = 10
	defense = 2
	move_speed = 45.0
	attack_interval = 1.6
	experience = 7
	sprite.color = Color(0.4, 0.5, 0.2, 1)

func _perform_attack():
	attack_area.monitoring = true
	await get_tree().create_timer(0.2).timeout
	attack_area.monitoring = false

func _on_attack_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(attack_power, global_position)
