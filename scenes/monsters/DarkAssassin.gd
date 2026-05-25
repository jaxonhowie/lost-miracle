extends "res://scenes/monsters/BaseMonster.gd"

func _setup_stats():
	monster_id = "dark_assassin"
	super()
	sprite.color = Color(0.2, 0.15, 0.3, 1)
	sprite.size = Vector2(32, 40)

	skills = [
		{
			"name": "Shadow Strike",
			"cooldown": 5.0,
			"timer": 2.0,
			"range": 150.0,
			"execute": _shadow_strike
		}
	]

func _shadow_strike():
	if not is_instance_valid(player_ref):
		return
	# Teleport behind player
	var behind_dir = -1 if player_ref.facing_right else 1
	var target = player_ref.global_position + Vector2(behind_dir * 30, 0)

	# Fade out
	sprite.modulate.a = 0.2
	var tween = create_tween()
	tween.tween_property(self, "global_position", target, 0.2)
	await tween.finished

	# Strike
	sprite.modulate.a = 1.0
	if is_instance_valid(player_ref) and player_ref.has_method("take_damage"):
		var dmg = int(attack_power * 1.5)
		player_ref.take_damage(dmg, global_position)

	# Flash
	sprite.color = Color(0.5, 0.2, 0.8, 1.0)
	await get_tree().create_timer(0.2).timeout
	sprite.color = Color(0.2, 0.15, 0.3, 1)
