extends PanelContainer

var is_open: bool = false
var enhance_sys: Node
var inv: Node

var selected_uid: String = ""

@onready var equip_option: OptionButton = $VBoxContainer/EquipOptionButton
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var rate_label: Label = $VBoxContainer/RateLabel
@onready var materials_label: Label = $VBoxContainer/MaterialsLabel
@onready var core_check: CheckBox = $VBoxContainer/CoreCheck
@onready var enhance_btn: Button = $VBoxContainer/EnhanceButton
@onready var result_label: Label = $VBoxContainer/ResultLabel

func _ready():
	visible = false
	enhance_sys = get_node_or_null("/root/EnhanceSystem")
	inv = get_node_or_null("/root/InventorySystem")

	if inv:
		inv.inventory_changed.connect(_refresh_equips)
	if enhance_sys:
		enhance_sys.enhance_result.connect(_on_enhance_result)

	equip_option.item_selected.connect(_on_equip_selected)
	enhance_btn.pressed.connect(_on_enhance_pressed)
	core_check.toggled.connect(_on_core_toggled)

func _input(event):
	if event.is_action_pressed("enhance"):
		toggle()

func toggle():
	is_open = !is_open
	visible = is_open
	if is_open:
		_refresh_equips()

func _refresh_equips():
	equip_option.clear()
	selected_uid = ""

	if not inv:
		return

	var equips = inv.get_all_equipment()
	for equip in equips:
		var item_data = ItemDatabase.get_item(equip["item_id"])
		var name = item_data.get("name", "?")
		var level = equip.get("enhance_level", 0)
		var display = name
		if level > 0:
			display += " +" + str(level)
		if level >= 10:
			display += " (MAX)"
		equip_option.add_item(display, equip_option.item_count)
		equip_option.set_item_metadata(equip_option.item_count - 1, equip["uid"])

	if equip_option.item_count > 0:
		equip_option.select(0)
		_on_equip_selected(0)
	else:
		info_label.text = "背包中没有可强化的装备"
		enhance_btn.disabled = true

func _on_equip_selected(index: int):
	selected_uid = equip_option.get_item_metadata(index)
	_update_enhance_info()

func _on_core_toggled(_pressed: bool):
	_update_enhance_info()

func _update_enhance_info():
	if selected_uid == "" or not enhance_sys:
		return

	var info = enhance_sys.get_enhance_info(selected_uid)
	if info.get("max_level", false):
		info_label.text = "已达到最大强化等级"
		rate_label.text = ""
		materials_label.text = ""
		enhance_btn.disabled = true
		return

	var current_level = info["current_level"]
	var item_data = ItemDatabase.get_item(inv.get_by_uid(selected_uid)["item_id"])
	info_label.text = item_data.get("name", "?") + " +" + str(current_level) + " -> +" + str(current_level + 1)

	var rate = info["final_rate"]
	rate_label.text = "成功率: %d%%" % int(rate * 100)

	# Materials
	var stone_name = ItemDatabase.get_item_name(info["stone_id"])
	var stone_text = "%s x%d" % [stone_name, info["stone_count"]]
	if info["has_stone"]:
		materials_label.text = "需要: " + stone_text + " ✓"
	else:
		materials_label.text = "需要: " + stone_text + " ✗"

	# Core
	core_check.disabled = not info["use_core"]
	if info["use_core"]:
		core_check.text = "使用Boss强化核心 (+20%%) ✓"
	else:
		core_check.text = "使用Boss强化核心 (无)"

	enhance_btn.disabled = not info["has_stone"]
	result_label.text = ""

func _on_enhance_pressed():
	if selected_uid == "" or not enhance_sys:
		return

	var use_core = core_check.button_pressed and not core_check.disabled
	var result = enhance_sys.try_enhance(selected_uid, use_core)

	if not result["success"] and result.has("error"):
		match result["error"]:
			"no_stone":
				result_label.text = "材料不足!"
			"max_level":
				result_label.text = "已达最大等级!"

func _on_enhance_result(uid: String, success: bool, new_level: int):
	if success:
		result_label.text = "强化成功! +" + str(new_level)
		result_label.modulate = Color.GREEN
	else:
		var old_level = new_level + 1
		if new_level < old_level:
			result_label.text = "强化失败... 降至 +" + str(new_level)
		else:
			result_label.text = "强化失败"
		result_label.modulate = Color.RED

	# Reset color after delay
	await get_tree().create_timer(2.0).timeout
	result_label.modulate = Color.WHITE

	_refresh_equips()
