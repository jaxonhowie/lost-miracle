extends Area2D

var _player_nearby: bool = false
var _hint_label: Label = null

func _ready():
	_hint_label = Label.new()
	_hint_label.text = "[E] 返回遗忘地牢"
	_hint_label.position = Vector2(-55, -50)
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.visible = false
	add_child(_hint_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Pulsing effect
	var tween = create_tween().set_loops()
	tween.tween_property(self, "modulate", Color(1.0, 0.8, 0.3, 0.8), 1.2)
	tween.tween_property(self, "modulate", Color(0.8, 0.6, 0.2, 1.0), 1.2)

func _on_body_entered(body):
	if body.is_in_group("player"):
		_player_nearby = true
		_hint_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		_player_nearby = false
		_hint_label.visible = false

func _input(event):
	if _player_nearby and event.is_action_pressed("equipment"):
		var save_sys = get_node_or_null("/root/SaveSystem")
		if save_sys:
			save_sys.save_game()
		get_tree().change_scene_to_file("res://scenes/maps/DungeonFloor1.tscn")
