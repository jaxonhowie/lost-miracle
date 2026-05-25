extends "res://scenes/monsters/BaseMonster.gd"

var _toxic_cloud_scene: PackedScene

func _setup_stats():
	monster_id = "zombie"
	super()
	sprite.color = Color(0.4, 0.5, 0.2, 1)

	skills = [
		{
			"name": "Toxic Cloud",
			"cooldown": 8.0,
			"timer": 4.0,
			"range": 100.0,
			"execute": _toxic_cloud
		}
	]

func _toxic_cloud():
	# Create a damaging area at current position
	var cloud = Area2D.new()
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	cloud.add_child(shape)
	cloud.global_position = global_position + Vector2(0, 10)
	get_parent().add_child(cloud)

	# Visual indicator
	var visual = ColorRect.new()
	visual.size = Vector2(80, 80)
	visual.position = Vector2(-40, -40)
	visual.color = Color(0.3, 0.6, 0.1, 0.4)
	cloud.add_child(visual)

	# Damage over time
	for i in range(3):
		await get_tree().create_timer(0.8).timeout
		for body in cloud.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(int(attack_power * 0.5), global_position)

	# Cleanup
	cloud.queue_free()

func _perform_attack():
	attack_area.monitoring = true
	await get_tree().create_timer(0.2).timeout
	attack_area.monitoring = false

func _on_attack_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(attack_power, global_position)
