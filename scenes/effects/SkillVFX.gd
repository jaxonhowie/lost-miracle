extends Node

static func spawn_whirlwind(parent: Node, pos: Vector2):
	var effect = CPUParticles2D.new()
	effect.position = pos
	effect.amount = 12
	effect.lifetime = 0.4
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.direction = Vector2(0, -1)
	effect.spread = 180.0
	effect.initial_velocity_min = 80.0
	effect.initial_velocity_max = 150.0
	effect.gravity = Vector2.ZERO
	effect.scale_amount_min = 2.0
	effect.scale_amount_max = 5.0
	effect.color = Color(1, 0.8, 0.3)
	parent.add_child(effect)
	effect.emitting = true
	_auto_free(effect, 0.5)

static func spawn_charge_trail(parent: Node, pos: Vector2):
	var effect = CPUParticles2D.new()
	effect.position = pos
	effect.amount = 4
	effect.lifetime = 0.15
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.direction = Vector2(0, -1)
	effect.spread = 40.0
	effect.initial_velocity_min = 20.0
	effect.initial_velocity_max = 50.0
	effect.gravity = Vector2(0, 100)
	effect.scale_amount_min = 2.0
	effect.scale_amount_max = 3.0
	effect.color = Color(0.3, 0.8, 1.0)
	parent.add_child(effect)
	effect.emitting = true
	_auto_free(effect, 0.25)

static func spawn_war_cry(parent: Node, pos: Vector2):
	var effect = CPUParticles2D.new()
	effect.position = pos
	effect.amount = 16
	effect.lifetime = 0.35
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.direction = Vector2(0, -1)
	effect.spread = 180.0
	effect.initial_velocity_min = 100.0
	effect.initial_velocity_max = 200.0
	effect.gravity = Vector2.ZERO
	effect.scale_amount_min = 3.0
	effect.scale_amount_max = 6.0
	effect.color = Color(1, 0.9, 0.2)
	parent.add_child(effect)
	effect.emitting = true
	_auto_free(effect, 0.45)

static func _auto_free(effect: CPUParticles2D, delay: float):
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(effect.queue_free)
	timer.timeout.connect(timer.queue_free)
	effect.add_child(timer)
	timer.start()
