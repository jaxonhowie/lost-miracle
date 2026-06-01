extends Node

const SETTINGS_PATH = "user://settings.json"

signal settings_changed

var _settings: Dictionary = {}
var _default_bindings: Dictionary = {}

const GAME_ACTIONS = [
	"ui_left", "ui_right", "attack", "skill_1", "skill_2", "skill_3",
	"dodge", "use_item_1", "inventory", "equipment", "enhance",
	"pause", "talent_panel", "quest_panel",
]

func _ready():
	_load_settings()
	_apply_fullscreen()
	_snapshot_default_bindings()
	_apply_keybindings()

func _load_settings():
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				_settings = json.data
	if not _settings.has("volume"):
		_settings["volume"] = {"Master": 80, "Music": 80, "SFX": 80}
	if not _settings.has("fullscreen"):
		_settings["fullscreen"] = false
	if not _settings.has("keybindings"):
		_settings["keybindings"] = {}

func _save_settings():
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_settings, "\t"))

# --- Volume ---

func get_volume(bus_name: String) -> float:
	return _settings["volume"].get(bus_name, 80.0)

func set_volume(bus_name: String, value_0_100: float):
	_settings["volume"][bus_name] = clampf(value_0_100, 0, 100)
	_apply_bus_volume(bus_name)
	_save_settings()
	settings_changed.emit()

func _apply_bus_volume(bus_name: String):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var val = _settings["volume"].get(bus_name, 80.0)
	if val <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(val / 100.0))

# --- Fullscreen ---

func is_fullscreen() -> bool:
	return _settings["fullscreen"]

func set_fullscreen(enabled: bool):
	_settings["fullscreen"] = enabled
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()
	settings_changed.emit()

func _apply_fullscreen():
	if _settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

# --- Keybindings ---

func _snapshot_default_bindings():
	for action in GAME_ACTIONS:
		_default_bindings[action] = InputMap.action_get_events(action).duplicate()

func _apply_keybindings():
	var kb = _settings["keybindings"]
	for action in kb:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for evt_dict in kb[action]:
			var evt = _deserialize_event(evt_dict)
			if evt:
				InputMap.action_add_event(action, evt)

func rebind_action(action: String, event: InputEvent):
	if not _settings["keybindings"].has(action):
		_settings["keybindings"][action] = []
	var serialized = _serialize_event(event)
	_settings["keybindings"][action] = [serialized]
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_save_settings()
	settings_changed.emit()

func reset_bindings():
	_settings["keybindings"] = {}
	for action in _default_bindings:
		InputMap.action_erase_events(action)
		for evt in _default_bindings[action]:
			InputMap.action_add_event(action, evt)
	_save_settings()
	settings_changed.emit()

func get_binding_display(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.is_empty():
		return "无"
	return _event_to_display(events[0])

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "physical_keycode": event.physical_keycode, "keycode": event.keycode}
	elif event is InputEventMouseButton:
		return {"type": "mouse", "button_index": event.button_index}
	return {}

func _deserialize_event(d: Dictionary) -> InputEvent:
	if d.get("type") == "key":
		var evt = InputEventKey.new()
		evt.physical_keycode = d.get("physical_keycode", 0)
		evt.keycode = d.get("keycode", 0)
		return evt
	elif d.get("type") == "mouse":
		var evt = InputEventMouseButton.new()
		evt.button_index = d.get("button_index", 1)
		return evt
	return null

func _event_to_display(event: InputEvent) -> String:
	if event is InputEventKey:
		return event.as_text()
	elif event is InputEventMouseButton:
		match event.button_index:
			1: return "鼠标左键"
			2: return "鼠标右键"
			3: return "鼠标中键"
			_: return "鼠标%d" % event.button_index
	return "未知"
