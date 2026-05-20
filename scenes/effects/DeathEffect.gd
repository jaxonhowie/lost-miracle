extends CPUParticles2D

static func spawn(parent: Node, pos: Vector2, color: Color = Color(0.5, 0.4, 0.3)):
	var effect = CPUParticles2D.new()
	effect.position = pos
	effect.amount = 16
	effect.lifetime = 0.6
	effect.one_shot = true
	effect.explosiveness = 0.8
	effect.direction = Vector2(0, -1)
	effect.spread = 80.0
	effect.initial_velocity_min = 40.0
	effect.initial_velocity_max = 100.0
	effect.gravity = Vector2(0, 150)
	effect.scale_amount_min = 3.0
	effect.scale_amount_max = 6.0
	effect.color = color
	effect.damping_min = 2.0
	effect.damping_max = 4.0
	parent.add_child(effect)
	# Auto-cleanup
	effect.emitting = true
	var timer = Timer.new()
	timer.wait_time = effect.lifetime + 0.2
	timer.one_shot = true
	timer.timeout.connect(effect.queue_free)
	timer.timeout.connect(timer.queue_free)
	effect.add_child(timer)
	timer.start()
	return effect
