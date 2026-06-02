extends "res://scenes/summons/BaseSummon.gd"

var aoe_radius: float = 60.0

func _ready():
	super._ready()
	sprite.color = Color(1.0, 0.4, 0.2, 0.8)

func _perform_attack():
	# AOE attack - hit all monsters in radius
	var hit_any = false
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster.has_method("take_damage") and monster.current_state != 5:
			var dist = global_position.distance_to(monster.global_position)
			if dist <= aoe_radius:
				monster.take_damage(attack_power, global_position, false)
				hit_any = true
	if hit_any:
		# Fire explosion effect
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)

func setup(p_summoner: Node2D, p_attack: int, p_duration: float):
	super.setup(p_summoner, p_attack, p_duration)
	attack_range = 80.0  # Fire spirit has shorter range but AOE
