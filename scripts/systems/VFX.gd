extends Node

var _cam: Camera2D = null
var _shake_id: int = 0

var _flash_layer: CanvasLayer
var _flash_rect: ColorRect

func _ready():
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 100
	_flash_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_flash_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color.WHITE
	_flash_rect.modulate.a = 0.0
	_flash_layer.add_child(_flash_rect)

func _get_cam() -> Camera2D:
	if not is_instance_valid(_cam):
		var p = get_tree().get_first_node_in_group("player")
		if p:
			_cam = p.get_node_or_null("Camera2D")
	return _cam

func shake(intensity: float = 4.0, duration: float = 0.15):
	var cam = _get_cam()
	if not cam:
		return
	_shake_id += 1
	var my_id = _shake_id
	var elapsed := 0.0
	while elapsed < duration:
		if _shake_id != my_id:
			return
		cam.offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	if _shake_id == my_id:
		cam.offset = Vector2.ZERO

func hitstop(duration_ms: int = 50):
	Engine.time_scale = 0.0
	var target = Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < target:
		await get_tree().process_frame
	Engine.time_scale = 1.0

func flash(color: Color, duration: float = 0.1):
	_flash_rect.color = color
	_flash_rect.modulate.a = 0.3
	var tw = _flash_rect.create_tween()
	tw.tween_property(_flash_rect, "modulate:a", 0.0, duration)
