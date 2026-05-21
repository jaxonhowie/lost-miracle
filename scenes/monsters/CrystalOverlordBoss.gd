extends "res://scenes/monsters/BaseMonster.gd"

var _phase: int = 1
var _phase2_triggered: bool = false
var _phase3_triggered: bool = false

func _setup_stats():
	monster_id = "crystal_overlord_boss"
	super()
	sprite.color = Color(0.2, 0.5, 0.9, 1)
	sprite.size = Vector2(80, 80)

	skills.append({
		"name": "crystal_slam",
		"cooldown": 3.5,
		"timer": 2.0,
		"range": 70.0,
		"execute": _crystal_slam,
	})
	skills.append({
		"name": "crystal_storm",
		"cooldown": 8.0,
		"timer": 5.0,
		"range": 200.0,
		"execute": _crystal_storm,
	})
	skills.append({
		"name": "crystal_shatter",
		"cooldown": 12.0,
		"timer": 8.0,
		"range": -1.0,
		"execute": _crystal_shatter,
	})

func _crystal_slam():
	if not is_instance_valid(player_ref):
		return
	# Lunge forward and slam
	var dir = (player_ref.global_position - global_position).normalized()
	var tween = create_tween()
	tween.tween_property(self, "global_position", global_position + dir * 50, 0.2)
	await tween.finished
	if is_instance_valid(player_ref) and _player_in_range(80):
		player_ref.take_damage(int(attack_power * 1.5), global_position)

func _crystal_storm():
	# AoE around boss
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if global_position.distance_to(p.global_position) < 150:
			p.take_damage(int(attack_power * 0.8), global_position)
	# Visual feedback
	sprite.modulate = Color(0.5, 0.8, 1.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.2, 0.5, 0.9), 0.4)

func _crystal_shatter():
	# Phase-based: spawns crystal shards (projectiles as areas)
	for i in range(4):
		var shard = Area2D.new()
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(12, 12)
		shape.shape = rect
		shard.add_child(shape)
		var visual = ColorRect.new()
		visual.size = Vector2(12, 12)
		visual.position = Vector2(-6, -6)
		visual.color = Color(0.4, 0.7, 1.0)
		shard.add_child(visual)
		shard.position = global_position
		shard.collision_layer = 0
		shard.collision_mask = 1
		get_parent().add_child(shard)
		var angle = i * PI / 2 + randf_range(-0.3, 0.3)
		var speed = 200.0
		var dir = Vector2(cos(angle), sin(angle))
		var tween = shard.create_tween()
		tween.tween_property(shard, "position", shard.position + dir * 200, 0.6)
		tween.tween_callback(shard.queue_free)
		shard.body_entered.connect(func(body):
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(int(attack_power * 0.6), global_position))

func _on_hp_changed(new_hp: int, max_hp_val: int):
	var ratio = float(new_hp) / float(max_hp_val)
	if ratio < 0.6 and not _phase2_triggered:
		_phase2_triggered = true
		_phase = 2
		sprite.color = Color(0.1, 0.3, 0.8)
		sprite.size = Vector2(90, 90)
	if ratio < 0.3 and not _phase3_triggered:
		_phase3_triggered = true
		_phase = 3
		sprite.color = Color(0.0, 0.2, 0.7)
		sprite.size = Vector2(100, 100)
