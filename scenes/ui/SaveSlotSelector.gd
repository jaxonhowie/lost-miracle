extends PanelContainer

var _mode: String = "load"  # "load" or "new"
var _confirming_slot: int = -1
var _pending_slot: int = -1

@onready var class_select: PanelContainer = $ClassSelectPanel

func _ready():
	visible = false
	$VBox/Slot1Btn.pressed.connect(_on_slot_pressed.bind(1))
	$VBox/Slot2Btn.pressed.connect(_on_slot_pressed.bind(2))
	$VBox/Slot3Btn.pressed.connect(_on_slot_pressed.bind(3))
	$VBox/BackBtn.pressed.connect(_on_back)
	$VBox/ConfirmPanel.visible = false
	$VBox/ConfirmPanel/VBox/HBox/YesBtn.pressed.connect(_on_confirm_yes)
	$VBox/ConfirmPanel/VBox/HBox/NoBtn.pressed.connect(_on_confirm_no)
	if class_select:
		class_select.class_selected.connect(_on_class_selected)

func show_mode(mode: String):
	_mode = mode
	_confirming_slot = -1
	_pending_slot = -1
	$VBox/ConfirmPanel.visible = false
	_refresh_slots()
	visible = true

func _refresh_slots():
	var save_sys = get_node_or_null("/root/SaveSystem")
	if not save_sys:
		return
	for i in range(1, 4):
		var btn: Button = $VBox.get_node("Slot%dBtn" % i)
		var meta = save_sys.get_slot_metadata(i)
		if meta.is_empty():
			btn.text = "存档 %d: 空" % i
			btn.disabled = (_mode == "load")
		else:
			var time_str = _format_playtime(meta["playtime"])
			var ts = meta["timestamp"]
			if ts.length() > 10:
				ts = ts.substr(0, 10)
			var class_name = meta.get("class_name", "战士")
			btn.text = "存档 %d: %s Lv.%d | %s | %d层 | %s" % [i, class_name, meta["level"], time_str, meta["floor"], ts]
			btn.disabled = false

func _format_playtime(seconds: float) -> String:
	var total_sec = int(seconds)
	var hours = total_sec / 3600
	var minutes = (total_sec % 3600) / 60
	return "%02d:%02d" % [hours, minutes]

func _on_slot_pressed(slot: int):
	var save_sys = get_node_or_null("/root/SaveSystem")
	if not save_sys:
		return

	if _mode == "load":
		save_sys.set_active_slot(slot)
		save_sys.load_game()
		get_tree().change_scene_to_file("res://scenes/maps/DungeonFloor1.tscn")
	else:  # new
		if save_sys.has_slot(slot):
			_confirming_slot = slot
			$VBox/ConfirmPanel/VBox/Label.text = "存档 %d 已有数据，\n开始新游戏将覆盖该存档。\n确定继续？" % slot
			$VBox/ConfirmPanel.visible = true
		else:
			_show_class_select(slot)

func _show_class_select(slot: int):
	_pending_slot = slot
	if class_select:
		class_select.show_panel()

func _on_class_selected(class_id: String):
	if _pending_slot <= 0:
		return
	_start_on_slot(_pending_slot)
	_pending_slot = -1

func _start_on_slot(slot: int):
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys:
		save_sys.delete_slot(slot)
		save_sys.set_active_slot(slot)
	get_tree().change_scene_to_file("res://scenes/maps/DungeonFloor1.tscn")

func _on_confirm_yes():
	$VBox/ConfirmPanel.visible = false
	if _confirming_slot > 0:
		_show_class_select(_confirming_slot)
	_confirming_slot = -1

func _on_confirm_no():
	$VBox/ConfirmPanel.visible = false
	_confirming_slot = -1

func _on_back():
	visible = false
