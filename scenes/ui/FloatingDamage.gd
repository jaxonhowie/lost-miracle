extends Label

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.8
var elapsed: float = 0.0

func setup(damage: int, is_crit: bool = false):
	text = str(damage)
	if is_crit:
		modulate = Color(1.0, 0.9, 0.1)
		add_theme_font_size_override("font_size", 22)
	else:
		modulate = Color(1.0, 0.3, 0.3)
		add_theme_font_size_override("font_size", 16)
	horizontal_alignment = HORIZONTAL_ALIGNMENT.CENTER
	# Random horizontal offset
	velocity = Vector2(randf_range(-30, 30), -80)

func _process(delta):
	elapsed += delta
	position += velocity * delta
	velocity.y += 40 * delta  # slight gravity
	modulate.a = 1.0 - (elapsed / lifetime)
	if elapsed >= lifetime:
		queue_free()
