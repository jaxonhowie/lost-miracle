extends CanvasLayer

var _queue: Array = []
var _showing: bool = false

func _ready():
	layer = 95
	# Connect to achievement system
	var ach_sys = get_node_or_null("/root/AchievementSystem")
	if ach_sys:
		ach_sys.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(achievement_id: String):
	var ach_sys = get_node_or_null("/root/AchievementSystem")
	if not ach_sys:
		return
	var ach_data = ach_sys._achievements.get(achievement_id, {})
	_queue.append(ach_data)
	if not _showing:
		_show_next()

func _show_next():
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var ach_data = _queue.pop_front()
	_create_toast(ach_data)

func _create_toast(ach_data: Dictionary):
	var panel = PanelContainer.new()
	panel.z_index = 100

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = Color(1, 0.85, 0.0, 0.8)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var title_label = Label.new()
	title_label.text = "成就解锁!"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.0))
	vbox.add_child(title_label)

	var name_label = Label.new()
	name_label.text = ach_data.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = ach_data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(desc_label)

	var reward = ach_data.get("reward_gold", 0)
	if reward > 0:
		var reward_label = Label.new()
		reward_label.text = "+%d 金币" % reward
		reward_label.add_theme_font_size_override("font_size", 13)
		reward_label.add_theme_color_override("font_color", Color(1, 0.85, 0.0))
		vbox.add_child(reward_label)

	panel.add_child(vbox)
	add_child(panel)

	# Position: right side, vertically centered
	var screen_w = 1280
	panel.position = Vector2(screen_w + 10, 100)
	panel.size = Vector2(0, 0)  # auto-size

	# Animation: slide in -> wait -> slide out
	var tween = create_tween()
	tween.tween_property(panel, "position:x", screen_w - 260, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(2.5)
	tween.tween_property(panel, "position:x", screen_w + 10, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(panel.queue_free)
	tween.tween_callback(_show_next)
