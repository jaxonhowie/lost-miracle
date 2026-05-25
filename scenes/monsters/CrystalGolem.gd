extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	monster_id = "crystal_golem"
	super()
	sprite.color = Color(0.4, 0.7, 0.9, 1)
	sprite.size = Vector2(48, 48)

	skills = [
		{
			"name": "Crystal Slam",
			"cooldown": 7.0,
			"timer": 3.0,
			"range": 80.0,
			"execute": _crystal_slam
		}
	]

func _crystal_slam():
	# AoE attack hitting all nearby players
	var total_dmg = int(attack_power * 1.5)
	sprite.color = Color(0.7, 0.9, 1.0, 1.0)

	# Visual shockwave
	var shockwave = ColorRect.new()
	shockwave.size = Vector2(160, 160)
	shockwave.position = Vector2(-80, -80)
	shockwave.color = Color(0.4, 0.7, 0.9, 0.4)
	get_parent().add_child(shockwave)
	shockwave.global_position = global_position + Vector2(0, -10)

	# Damage all players in range
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("take_damage"):
			var dist = global_position.distance_to(player.global_position)
			if dist <= 100.0:
				player.take_damage(total_dmg, global_position)

	# Shake
	VFX.shake(4.0, 0.2)

	await get_tree().create_timer(0.3).timeout
	shockwave.queue_free()
	sprite.color = Color(0.4, 0.7, 0.9, 1)
