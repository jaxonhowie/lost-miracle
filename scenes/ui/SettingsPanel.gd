extends CanvasLayer

const ACTION_NAMES = {
	"ui_left": "移动 - 左",
	"ui_right": "移动 - 右",
	"attack": "攻击",
	"skill_1": "技能 1",
	"skill_2": "技能 2",
	"skill_3": "技能 3",
	"dodge": "闪避",
	"use_item_1": "快捷物品 1",
	"inventory": "背包",
	"equipment": "装备",
	"enhance": "强化",
	"pause": "暂停",
	"talent_panel": "天赋",
	"quest_panel": "任务",
}

const ACTION_ORDER = [
	"ui_left", "ui_right", "attack", "skill_1", "skill_2", "skill_3",
	"dodge", "use_item_1", "inventory", "equipment", "enhance",
	"pause", "talent_panel", "quest_panel",
]

var _listening: bool = false
var _rebinding_action: String = ""
var _rebind_button: Button = null
var _keybind_buttons: Dictionary = {}
var _updating_sliders: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	$Panel.visible = false

	# Volume sliders
	$Panel/VBox/AudioSection/MasterRow/Slider.value_changed.connect(_on_master_volume.bind())
	$Panel/VBox/AudioSection/MusicRow/Slider.value_changed.connect(_on_music_volume.bind())
	$Panel/VBox/AudioSection/SFXRow/Slider.value_changed.connect(_on_sfx_volume.bind())

	# Fullscreen checkbox
	$Panel/VBox/FullscreenCheck.toggled.connect(_on_fullscreen_toggled.bind())

	# Buttons
	$Panel/VBox/Footer/ResetBtn.pressed.connect(_on_reset_bindings)
	$Panel/VBox/Footer/CloseBtn.pressed.connect(_on_close)

	_build_keybind_list()
	_load_current_values()

func toggle():
	if $Panel.visible:
		_on_close()
	else:
		_load_current_values()
		$Panel.visible = true

func _load_current_values():
	var settings = get_node_or_null("/root/SettingsSystem")
	if not settings:
		return
	_updating_sliders = true
	$Panel/VBox/AudioSection/MasterRow/Slider.value = settings.get_volume("Master")
	$Panel/VBox/AudioSection/MusicRow/Slider.value = settings.get_volume("Music")
	$Panel/VBox/AudioSection/SFXRow/Slider.value = settings.get_volume("SFX")
	$Panel/VBox/AudioSection/MasterRow/Value.text = "%d" % int(settings.get_volume("Master"))
	$Panel/VBox/AudioSection/MusicRow/Value.text = "%d" % int(settings.get_volume("Music"))
	$Panel/VBox/AudioSection/SFXRow/Value.text = "%d" % int(settings.get_volume("SFX"))
	$Panel/VBox/FullscreenCheck.button_pressed = settings.is_fullscreen()
	_updating_sliders = false
	_refresh_keybind_display()

func _build_keybind_list():
	var list = $Panel/VBox/KeybindSection/Scroll/List
	for child in list.get_children():
		child.queue_free()
	await get_tree().process_frame

	for action in ACTION_ORDER:
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 30)

		var label = Label.new()
		label.text = ACTION_NAMES.get(action, action)
		label.custom_minimum_size = Vector2(180, 0)
		row.add_child(label)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 0)
		btn.pressed.connect(_on_rebind_click.bind(action, btn))
		row.add_child(btn)

		_keybind_buttons[action] = btn
		list.add_child(row)

func _refresh_keybind_display():
	var settings = get_node_or_null("/root/SettingsSystem")
	if not settings:
		return
	for action in _keybind_buttons:
		var btn = _keybind_buttons[action] as Button
		btn.text = settings.get_binding_display(action)
		btn.disabled = false

func _on_rebind_click(action: String, btn: Button):
	if _listening:
		_cancel_listen()
	_rebinding_action = action
	_rebind_button = btn
	_listening = true
	btn.text = "请按键..."
	btn.disabled = true

func _cancel_listen():
	_listening = false
	if _rebind_button:
		var settings = get_node_or_null("/root/SettingsSystem")
		if settings:
			_rebind_button.text = settings.get_binding_display(_rebinding_action)
		_rebind_button.disabled = false
	_rebinding_action = ""
	_rebind_button = null

func _input(event):
	if not _listening:
		return
	if not $Panel.visible:
		return

	# Escape cancels rebind
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_cancel_listen()
		get_viewport().set_input_as_handled()
		return

	# Accept key or mouse button
	if event is InputEventKey and event.pressed:
		_apply_rebind(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_apply_rebind(event)
		get_viewport().set_input_as_handled()

func _apply_rebind(event: InputEvent):
	var settings = get_node_or_null("/root/SettingsSystem")
	if not settings:
		_cancel_listen()
		return

	# Check conflict
	var conflict = _find_conflict(event, _rebinding_action)
	if conflict != "":
		if _rebind_button:
			_rebind_button.text = "冲突: %s" % ACTION_NAMES.get(conflict, conflict)
		await get_tree().create_timer(1.5).timeout
		_cancel_listen()
		return

	settings.rebind_action(_rebinding_action, event)
	_listening = false
	if _rebind_button:
		_rebind_button.text = settings.get_binding_display(_rebinding_action)
		_rebind_button.disabled = false
	_rebinding_action = ""
	_rebind_button = null

func _find_conflict(event: InputEvent, exclude_action: String) -> String:
	for action in ACTION_ORDER:
		if action == exclude_action:
			continue
		if not InputMap.has_action(action):
			continue
		for existing in InputMap.action_get_events(action):
			if _events_match(existing, event):
				return action
	return ""

func _events_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode and a.physical_keycode != 0
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false

func _on_master_volume(value: float):
	if _updating_sliders:
		return
	$Panel/VBox/AudioSection/MasterRow/Value.text = "%d" % int(value)
	var settings = get_node_or_null("/root/SettingsSystem")
	if settings:
		settings.set_volume("Master", value)

func _on_music_volume(value: float):
	if _updating_sliders:
		return
	$Panel/VBox/AudioSection/MusicRow/Value.text = "%d" % int(value)
	var settings = get_node_or_null("/root/SettingsSystem")
	if settings:
		settings.set_volume("Music", value)

func _on_sfx_volume(value: float):
	if _updating_sliders:
		return
	$Panel/VBox/AudioSection/SFXRow/Value.text = "%d" % int(value)
	var settings = get_node_or_null("/root/SettingsSystem")
	if settings:
		settings.set_volume("SFX", value)

func _on_fullscreen_toggled(pressed: bool):
	if _updating_sliders:
		return
	var settings = get_node_or_null("/root/SettingsSystem")
	if settings:
		settings.set_fullscreen(pressed)

func _on_reset_bindings():
	var settings = get_node_or_null("/root/SettingsSystem")
	if settings:
		settings.reset_bindings()
	_refresh_keybind_display()

func _on_close():
	if _listening:
		_cancel_listen()
	$Panel.visible = false
