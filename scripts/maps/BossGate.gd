extends StaticBody2D

var is_open: bool = false
var _player_nearby: bool = false
var _message_label: Label = null
var _message_timer: float = 0.0

const OPEN_DISTANCE: float = 200.0
@export var elite_1_id: String = "elite_1"
@export var elite_2_id: String = "elite_2"

func _ready():
	# Create message label
	_message_label = Label.new()
	_message_label.position = Vector2(-120, -80)
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.visible = false
	add_child(_message_label)

func _process(delta):
	if is_open:
		return

	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	var dist = global_position.distance_to(player.global_position)

	if dist < OPEN_DISTANCE:
		if not _player_nearby:
			_player_nearby = true
			_try_open()
	else:
		_player_nearby = false

	# Fade message
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			_message_label.visible = false

func _try_open():
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	if not spawn_sys:
		return

	# Check if both elites are dead (on cooldown)
	var e1 = spawn_sys.spawn_points.get(elite_1_id, {})
	var e2 = spawn_sys.spawn_points.get(elite_2_id, {})

	var e1_dead = e1.get("death_time", 0) > 0 or e1.get("monster_node") == null
	var e2_dead = e2.get("death_time", 0) > 0 or e2.get("monster_node") == null

	# If elites haven't been spawned yet (no entry), they're not dead
	if not spawn_sys.spawn_points.has(elite_1_id):
		e1_dead = false
	if not spawn_sys.spawn_points.has(elite_2_id):
		e2_dead = false

	if e1_dead and e2_dead:
		_open_gate()
	else:
		_show_message("需要先击败两位精英守卫")

func _open_gate():
	is_open = true
	# Tween: slide wall up
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 300, 1.0)
	tween.tween_callback(_disable_collision)

func _disable_collision():
	$Shape.set_deferred("disabled", true)

func _show_message(text: String):
	_message_label.text = text
	_message_label.visible = true
	_message_timer = 2.0
