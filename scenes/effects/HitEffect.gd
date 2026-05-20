extends CPUParticles2D

func _ready():
	emitting = true
	one_shot = true
	await get_tree().create_timer(lifetime + 0.1).timeout
	queue_free()

static func spawn(parent: Node, pos: Vector2, color: Color = Color(1, 0.3, 0.2)):
	var effect = CPUParticles2D.new()
	effect.position = pos
	effect.amount = 8
	effect.lifetime = 0.3
	effect.one_shot = true
	effect.explosiveness = 0.9
	effect.direction = Vector2(0, -1)
	effect.spread = 60.0
	effect.initial_velocity_min = 60.0
	effect.initial_velocity_max = 120.0
	effect.gravity = Vector2(0, 200)
	effect.scale_amount_min = 2.0
	effect.scale_amount_max = 4.0
	effect.color = color
	parent.add_child(effect)
	return effect
