extends "res://scenes/monsters/BaseMonster.gd"

var _curse_active: bool = false

func _setup_stats():
	monster_id = "wraith"
	super()
	sprite.color = Color(0.6, 0.5, 0.8, 0.7)
	sprite.size = Vector2(36, 44)

	skills = [
		{
			"name": "Curse",
			"cooldown": 12.0,
			"timer": 6.0,
			"range": 120.0,
			"execute": _curse_player
		}
	]

func _curse_player():
	if not is_instance_valid(player_ref):
		return
	# Reduce player attack and defense temporarily
	var talent_sys = player_ref.get_node_or_null("/root/TalentSystem")
	# Apply visual effect on player
	player_ref.sprite.modulate = Color(0.5, 0.2, 0.5, 1.0)
	# Curse reduces player's effective stats via a debuff
	if player_ref._buffs.has("curse"):
		player_ref._buffs.erase("curse")
	player_ref._buffs["curse"] = { "timer": 5.0, "value": 0.7 }
	# Visual feedback
	sprite.modulate = Color(0.8, 0.3, 1.0, 1.0)
	await get_tree().create_timer(0.3).timeout
	sprite.modulate = Color(0.6, 0.5, 0.8, 0.7)

func _perform_attack():
	# Wraith attack applies curse effect
	attack_area.monitoring = true
	await get_tree().create_timer(0.15).timeout
	attack_area.monitoring = false

func _on_attack_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(attack_power, global_position)
