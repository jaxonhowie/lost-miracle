extends Node

var _sprite: ColorRect
var _base_scale: Vector2
var _base_position: Vector2
var _base_color: Color

# Continuous animation state
var _breathe_active: bool = false
var _breathe_amplitude: float = 0.03
var _breathe_speed: float = 2.0
var _breathe_time: float = 0.0

var _bounce_active: bool = false
var _bounce_height: float = 3.0
var _bounce_speed: float = 8.0
var _bounce_time: float = 0.0

var _lean_target: float = 0.0
var _lean_current: float = 0.0

# Track active one-shot tweens to avoid conflicts
var _active_tweens: Dictionary = {}

func setup(sprite_node: ColorRect):
	_sprite = sprite_node
	_base_scale = _sprite.scale
	_base_position = _sprite.position
	_base_color = _sprite.color

func _process(delta):
	if not _sprite:
		return

	# Breathe: oscillate scale.y
	if _breathe_active:
		_breathe_time += delta * _breathe_speed
		var breath_offset = sin(_breathe_time) * _breathe_amplitude
		_sprite.scale.y = _base_scale.y * (1.0 + breath_offset)

	# Bounce: oscillate Y position offset
	if _bounce_active:
		_bounce_time += delta * _bounce_speed
		var bounce_offset = abs(sin(_bounce_time)) * _bounce_height
		_sprite.position.y = _base_position.y - bounce_offset

	# Lean: smooth rotation
	if abs(_lean_current - _lean_target) > 0.1:
		_lean_current = lerp(_lean_current, _lean_target, delta * 12.0)
		_sprite.rotation = deg_to_rad(_lean_current)
	else:
		_lean_current = _lean_target
		_sprite.rotation = deg_to_rad(_lean_target)

# --- Breathe ---

func breathe(amplitude := 0.03, speed := 2.0):
	_breathe_active = true
	_breathe_amplitude = amplitude
	_breathe_speed = speed
	_breathe_time = 0.0

func stop_breathe():
	_breathe_active = false
	if _sprite:
		_sprite.scale.y = _base_scale.y

# --- Bounce ---

func bounce(height := 3.0, speed := 8.0):
	_bounce_active = true
	_bounce_height = height
	_bounce_speed = speed
	_bounce_time = 0.0

func stop_bounce():
	_bounce_active = false
	if _sprite:
		_sprite.position.y = _base_position.y

# --- Squash & Stretch ---

func squash_stretch(intensity := 0.15, duration := 0.2):
	if not _sprite:
		return
	_kill_tween("squash_stretch")
	var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_active_tweens["squash_stretch"] = tw
	# Squash: wide + short, then recover
	var squash_scale = Vector2(_base_scale.x * (1.0 + intensity), _base_scale.y * (1.0 - intensity))
	tw.tween_property(_sprite, "scale", squash_scale, duration * 0.3)
	tw.tween_property(_sprite, "scale", _base_scale, duration * 0.7)

# --- Flash Color ---

func flash_color(color: Color, duration := 0.15):
	if not _sprite:
		return
	_kill_tween("flash_color")
	var tw = create_tween()
	_active_tweens["flash_color"] = tw
	_sprite.color = color
	tw.tween_interval(duration)
	tw.tween_callback(_restore_color_impl)

func restore_color():
	_kill_tween("flash_color")
	_restore_color_impl()

func _restore_color_impl():
	if _sprite:
		_sprite.color = _base_color

# --- Lean ---

func lean(angle_deg: float, _duration := 0.15):
	_lean_target = angle_deg

func reset_lean():
	_lean_target = 0.0

# --- Shake Local ---

func shake_local(intensity := 2.0, duration := 0.15):
	if not _sprite:
		return
	_kill_tween("shake_local")
	var tw = create_tween()
	_active_tweens["shake_local"] = tw
	var original_pos = _sprite.position
	var steps = int(duration / 0.03)
	for i in range(steps):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tw.tween_property(_sprite, "position", original_pos + offset, 0.03)
	tw.tween_property(_sprite, "position", _base_position, 0.03)

# --- Scale Punch ---

func scale_punch(target_scale := 1.2, duration := 0.15):
	if not _sprite:
		return
	_kill_tween("scale_punch")
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tweens["scale_punch"] = tw
	var punch = Vector2(_base_scale.x * target_scale, _base_scale.y * target_scale)
	tw.tween_property(_sprite, "scale", punch, duration * 0.3)
	tw.tween_property(_sprite, "scale", _base_scale, duration * 0.7)

# --- Fade Out ---

func fade_out(duration := 0.5) -> Tween:
	if not _sprite:
		return null
	_kill_tween("fade_out")
	var tw = create_tween()
	_active_tweens["fade_out"] = tw
	tw.tween_property(_sprite, "modulate:a", 0.0, duration)
	return tw

# --- Utility ---

func stop_all():
	_breathe_active = false
	_bounce_active = false
	_lean_target = 0.0
	_lean_current = 0.0
	for key in _active_tweens:
		if _active_tweens[key] and _active_tweens[key].is_valid():
			_active_tweens[key].kill()
	_active_tweens.clear()
	if _sprite:
		_sprite.scale = _base_scale
		_sprite.position = _base_position
		_sprite.rotation = 0.0
		_sprite.modulate.a = 1.0

func _kill_tween(key: String):
	if _active_tweens.has(key) and _active_tweens[key] and _active_tweens[key].is_valid():
		_active_tweens[key].kill()
	_active_tweens.erase(key)

func update_base_scale(new_scale: Vector2):
	_base_scale = new_scale

func update_base_color(new_color: Color):
	_base_color = new_color
