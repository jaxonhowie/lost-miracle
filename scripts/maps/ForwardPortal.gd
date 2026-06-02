extends Area2D

@export var target_scene: String = ""
@export var hint_text: String = "[E] 前进"
@export var boss_spawn_id: String = "boss_1"

var _player_nearby: bool = false
var _hint_label: Label = null
var _active: bool = false

func _ready():
	_hint_label = Label.new()
	_hint_label.text = hint_text
	_hint_label.position = Vector2(-60, -60)
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.visible = false
	add_child(_hint_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	await get_tree().process_frame
	_check_boss_status()

func _check_boss_status():
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	if not spawn_sys:
		return
	var boss_data = spawn_sys.spawn_points.get(boss_spawn_id, {})
	var boss_dead = boss_data.get("death_time", 0) > 0 or boss_data.get("monster_node") == null
	if not spawn_sys.spawn_points.has(boss_spawn_id):
		boss_dead = false
	if boss_dead:
		_activate()

func _activate():
	_active = true
	visible = true
	var tween = create_tween().set_loops()
	tween.tween_property(self, "modulate", Color(0.5, 0.3, 1.0, 0.8), 1.0)
	tween.tween_property(self, "modulate", Color(0.3, 0.2, 0.8, 1.0), 1.0)

func _on_body_entered(body):
	if body.is_in_group("player"):
		_player_nearby = true
		if _active:
			_hint_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		_player_nearby = false
		_hint_label.visible = false

func _input(event):
	if _player_nearby and _active and event.is_action_pressed("equipment"):
		var save_sys = get_node_or_null("/root/SaveSystem")
		if save_sys:
			save_sys.save_game()
		get_tree().change_scene_to_file(target_scene)
