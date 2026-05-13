extends Area2D

var damage: int = 10
var tick_interval: float = 0.5
var duration: float = 5.0
var source_position: Vector2

var _tick_timer: float = 0.0
var _duration_timer: float = 0.0
var _overlapping_player: Node2D = null

func setup(dmg: int, tick: float, dur: float, size: Vector2, source_pos: Vector2):
	damage = dmg
	tick_interval = tick
	duration = dur
	source_position = source_pos
	$CollisionShape2D.shape.size = size
	$SpritePlaceholder.size = size
	$SpritePlaceholder.position = -size / 2

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta):
	_duration_timer += delta
	if _duration_timer >= duration:
		queue_free()
		return
	_tick_timer += delta
	if _tick_timer >= tick_interval and _overlapping_player:
		_tick_timer = 0.0
		if _overlapping_player.has_method("take_damage"):
			_overlapping_player.take_damage(damage, source_position)

func _on_body_entered(body):
	if body.is_in_group("player"):
		_overlapping_player = body
		_tick_timer = tick_interval

func _on_body_exited(body):
	if body == _overlapping_player:
		_overlapping_player = null
