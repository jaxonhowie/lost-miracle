extends "res://scenes/monsters/BaseMonster.gd"

const SUMMON_COOLDOWN: float = 15.0
const SUMMON_RANGE: float = 150.0

func _setup_stats():
	monster_id = "elite_shadow_lord"
	super()
	sprite.color = Color(0.15, 0.08, 0.25, 1)
	sprite.size = Vector2(48, 56)
	skills.append({
		"name": "shadow_step",
		"cooldown": 6.0,
		"timer": 3.0,
		"range": 120.0,
		"execute": _shadow_step,
	})
	skills.append({
		"name": "summon_minions",
		"cooldown": SUMMON_COOLDOWN,
		"timer": 10.0,
		"range": -1.0,
		"execute": _summon_minions,
	})

func _shadow_step():
	if not is_instance_valid(player_ref):
		return
	var dir = (player_ref.global_position - global_position).normalized()
	var target = global_position + dir * 80
	# Quick teleport
	var tween = create_tween()
	tween.tween_property(self, "global_position", target, 0.15)
	sprite.modulate = Color(0.3, 0.1, 0.5, 0.5)
	await tween.finished
	sprite.modulate = Color(0.15, 0.08, 0.25, 1)

func _summon_minions():
	for i in range(2):
		var minion = preload("res://scenes/monsters/SummonedSkeleton.gd").new()
		var skeleton = CharacterBody2D.new()
		skeleton.set_script(preload("res://scenes/monsters/SummonedSkeleton.gd"))
		skeleton.global_position = global_position + Vector2(randf_range(-40, 40), -20)
		get_parent().add_child(skeleton)
