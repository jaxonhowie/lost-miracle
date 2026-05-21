extends HBoxContainer

const BUFF_COLORS: Dictionary = {
	"war_cry": Color(1.0, 0.85, 0.2),
	"speed": Color(0.2, 0.9, 0.9),
}

const BUFF_NAMES: Dictionary = {
	"war_cry": "战吼",
	"speed": "疾速",
}

var _player: Node2D = null
var _poll_timer: float = 0.0
const POLL_INTERVAL: float = 0.1

func _process(delta):
	_poll_timer -= delta
	if _poll_timer > 0:
		return
	_poll_timer = POLL_INTERVAL

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	_clear_icons()
	for buff_id in _player._buffs:
		var buff = _player._buffs[buff_id]
		var remaining = buff["timer"]
		_add_icon(buff_id, remaining)

func _clear_icons():
	for child in get_children():
		child.queue_free()

func _add_icon(buff_id: String, remaining: float):
	var color = BUFF_COLORS.get(buff_id, Color.WHITE)
	var display_name = BUFF_NAMES.get(buff_id, buff_id)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(40, 32)

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg.border_color = color
	bg.border_width_bottom = 2
	bg.border_width_top = 2
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", bg)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)

	var name_label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = color
	vbox.add_child(name_label)

	var time_label = Label.new()
	time_label.text = "%.1fs" % remaining
	time_label.add_theme_font_size_override("font_size", 10)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(time_label)

	panel.add_child(vbox)
	add_child(panel)
