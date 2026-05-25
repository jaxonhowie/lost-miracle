extends PanelContainer

var is_open: bool = false
var near_quest_npc: bool = false

@onready var tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var available_list: VBoxContainer = $VBoxContainer/TabContainer/Available/VBoxContainer
@onready var active_list: VBoxContainer = $VBoxContainer/TabContainer/Active/VBoxContainer
@onready var completed_list: VBoxContainer = $VBoxContainer/TabContainer/Completed/VBoxContainer
@onready var result_label: Label = $VBoxContainer/ResultLabel

func _ready():
	visible = false
	var quest_sys = get_node_or_null("/root/QuestSystem")
	if quest_sys:
		quest_sys.quest_accepted.connect(_on_quest_accepted)
		quest_sys.quest_completed.connect(_on_quest_completed)
		quest_sys.quest_progress.connect(_on_quest_progress)

func toggle():
	is_open = !is_open
	visible = is_open
	if is_open:
		_refresh()

func _refresh():
	_refresh_available()
	_refresh_active()
	_refresh_completed()

func _refresh_available():
	for child in available_list.get_children():
		child.queue_free()
	await get_tree().process_frame

	var quest_sys = get_node_or_null("/root/QuestSystem")
	if not quest_sys:
		return

	var quests = quest_sys.get_available_quests()
	if quests.is_empty():
		var label = Label.new()
		label.text = "暂无可用任务"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		available_list.add_child(label)
		return

	for quest in quests:
		var panel = _create_quest_entry(quest, "available")
		available_list.add_child(panel)

func _refresh_active():
	for child in active_list.get_children():
		child.queue_free()
	await get_tree().process_frame

	var quest_sys = get_node_or_null("/root/QuestSystem")
	if not quest_sys:
		return

	var quests = quest_sys.get_active_quests()
	if quests.is_empty():
		var label = Label.new()
		label.text = "没有进行中的任务"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		active_list.add_child(label)
		return

	for quest in quests:
		var panel = _create_quest_entry(quest, "active")
		active_list.add_child(panel)

func _refresh_completed():
	for child in completed_list.get_children():
		child.queue_free()
	await get_tree().process_frame

	var quest_sys = get_node_or_null("/root/QuestSystem")
	if not quest_sys:
		return

	var quests = quest_sys.get_completed_quests()
	if quests.is_empty():
		var label = Label.new()
		label.text = "尚未完成任何任务"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		completed_list.add_child(label)
		return

	for quest in quests:
		var panel = _create_quest_entry(quest, "completed")
		completed_list.add_child(panel)

func _create_quest_entry(quest: Dictionary, mode: String) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Title row
	var title_hbox = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = quest.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mode == "completed":
		name_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	title_hbox.add_child(name_label)

	var reward_label = Label.new()
	reward_label.text = "%d G" % quest.get("reward_gold", 0)
	reward_label.add_theme_font_size_override("font_size", 14)
	reward_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title_hbox.add_child(reward_label)
	vbox.add_child(title_hbox)

	# Description
	var desc_label = Label.new()
	desc_label.text = quest.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(desc_label)

	# Progress bar for active quests
	if mode == "active":
		var progress = quest.get("progress", 0)
		var target = quest.get("target_count", 1)
		var bar = ProgressBar.new()
		bar.max_value = target
		bar.value = progress
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 16)

		var bg = StyleBoxFlat.new()
		bg.bg_color = Color(0.2, 0.2, 0.2)
		bar.add_theme_stylebox_override("background", bg)
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.3, 0.6, 0.9)
		bar.add_theme_stylebox_override("fill", fill)

		vbox.add_child(bar)

		var progress_label = Label.new()
		progress_label.text = "%d / %d" % [progress, target]
		progress_label.add_theme_font_size_override("font_size", 12)
		progress_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(progress_label)

	# Accept button for available quests
	if mode == "available":
		var btn = Button.new()
		btn.text = "接受任务"
		btn.pressed.connect(_on_accept_pressed.bind(quest.get("id", "")))
		vbox.add_child(btn)

	# Completed mark
	if mode == "completed":
		var done_label = Label.new()
		done_label.text = "已完成"
		done_label.add_theme_font_size_override("font_size", 13)
		done_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(done_label)

	panel.add_child(vbox)
	return panel

func _on_accept_pressed(quest_id: String):
	var quest_sys = get_node_or_null("/root/QuestSystem")
	if quest_sys:
		quest_sys.accept_quest(quest_id)
		AudioManager.play_sfx("res://assets/audio/sfx_buy.ogg")
		_refresh()

func _on_quest_accepted(quest_id: String):
	var quest_sys = get_node_or_null("/root/QuestSystem")
	if quest_sys and quest_sys._quests.has(quest_id):
		var qname = quest_sys._quests[quest_id].get("name", quest_id)
		result_label.text = "接受任务: %s" % qname
		result_label.modulate = Color(0.5, 1.0, 0.5)
		_clear_result()

func _on_quest_completed(quest_id: String):
	var quest_sys = get_node_or_null("/root/QuestSystem")
	if quest_sys and quest_sys._quests.has(quest_id):
		var qname = quest_sys._quests[quest_id].get("name", quest_id)
		result_label.text = "任务完成: %s" % qname
		result_label.modulate = Color(1, 0.85, 0.0)
		_clear_result()
	if is_open:
		_refresh()

func _on_quest_progress(_quest_id: String, _current: int, _target: int):
	if is_open:
		_refresh()

func _clear_result():
	await get_tree().create_timer(2.0).timeout
	result_label.text = ""
	result_label.modulate = Color.WHITE
