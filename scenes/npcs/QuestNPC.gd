extends Area2D

var _player_nearby: bool = false
var _hint_label: Label = null
var _quest_panel: PanelContainer = null
var _exclaim_label: Label = null

func _ready():
	_hint_label = Label.new()
	_hint_label.text = "[Q] 任务"
	_hint_label.position = Vector2(-40, -60)
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.visible = false
	add_child(_hint_label)

	# Exclamation mark above head
	_exclaim_label = Label.new()
	_exclaim_label.text = "!"
	_exclaim_label.position = Vector2(-5, -75)
	_exclaim_label.add_theme_font_size_override("font_size", 24)
	_exclaim_label.add_theme_color_override("font_color", Color(1, 0.85, 0.0))
	_exclaim_label.visible = false
	add_child(_exclaim_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Find quest panel in UILayer
	await get_tree().process_frame
	var uilayer = get_node_or_null("../UILayer")
	if uilayer:
		_quest_panel = uilayer.get_node_or_null("QuestPanel")

	# Update exclamation mark
	_update_exclaim()

func _update_exclaim():
	var quest_sys = get_node_or_null("/root/QuestSystem")
	if not quest_sys:
		return
	var available = quest_sys.get_available_quests()
	_exclaim_label.visible = not available.is_empty()

func _on_body_entered(body):
	if body.is_in_group("player"):
		_player_nearby = true
		_hint_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		_player_nearby = false
		_hint_label.visible = false
		if _quest_panel and _quest_panel.is_open:
			_quest_panel.toggle()

func _input(event):
	if _player_nearby and event.is_action_pressed("quest_panel"):
		if _quest_panel and not _quest_panel.is_open:
			_quest_panel.toggle()
