extends Area2D

var damage: int = 15
var cycle_time: float = 2.0
var active_time: float = 1.0
var _timer: float = 0.0
var _is_active: bool = false
var _original_scale_y: float = 1.0

func _ready():
	_original_scale_y = scale.y
	scale.y = 0.1  # Start retracted
	_timer = randf_range(0, cycle_time)  # Random offset
	body_entered.connect(_on_body_entered)

func _process(delta):
	_timer += delta
	if _timer >= cycle_time:
		_timer -= cycle_time
		_extend()

func _extend():
	_is_active = true
	var tween = create_tween()
	tween.tween_property(self, "scale:y", _original_scale_y, 0.15)
	tween.tween_interval(active_time)
	tween.tween_property(self, "scale:y", 0.1, 0.15)
	tween.tween_callback(func(): _is_active = false)

func _on_body_entered(body):
	if _is_active and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
