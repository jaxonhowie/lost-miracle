extends PanelContainer

var is_open: bool = false
var inv: Node

# Filter & sort
var _current_filter: String = ""  # "", "equipment", "consumable", "material"
var _sort_mode: int = 0  # 0=default, 1=quality, 2=name
const SORT_LABELS = ["默认", "品质", "名称"]
const QUALITY_WEIGHT = {"epic": 4, "rare": 3, "fine": 2, "normal": 1}

var _last_pressed_item_id: String = ""
var _action_slot: Dictionary = {}

var _action_row: HBoxContainer = null

@onready var grid: GridContainer = $VBoxContainer/ScrollContainer/GridContainer
@onready var detail_label: Label = $VBoxContainer/DetailLabel
@onready var btn_all: Button = $VBoxContainer/FilterBar/BtnAll
@onready var btn_equip: Button = $VBoxContainer/FilterBar/BtnEquip
@onready var btn_consume: Button = $VBoxContainer/FilterBar/BtnConsume
@onready var btn_material: Button = $VBoxContainer/FilterBar/BtnMaterial
@onready var btn_sort: Button = $VBoxContainer/FilterBar/BtnSort

func _ready():
	visible = false
	inv = get_node_or_null("/root/InventorySystem")
	if inv:
		inv.inventory_changed.connect(_refresh)
	btn_all.pressed.connect(_on_filter.bind(""))
	btn_equip.pressed.connect(_on_filter.bind("equipment"))
	btn_consume.pressed.connect(_on_filter.bind("consumable"))
	btn_material.pressed.connect(_on_filter.bind("material"))
	btn_sort.pressed.connect(_on_sort_pressed)
	_update_filter_buttons()

func toggle():
	is_open = !is_open
	visible = is_open
	if is_open:
		_refresh()

func _on_filter(filter: String):
	_current_filter = filter
	_update_filter_buttons()
	_refresh()

func _on_sort_pressed():
	_sort_mode = (_sort_mode + 1) % SORT_LABELS.size()
	btn_sort.text = "排序:" + SORT_LABELS[_sort_mode]
	_refresh()

func _update_filter_buttons():
	btn_all.disabled = _current_filter == ""
	btn_equip.disabled = _current_filter == "equipment"
	btn_consume.disabled = _current_filter == "consumable"
	btn_material.disabled = _current_filter == "material"

func _refresh():
	# Clear grid
	for child in grid.get_children():
		child.queue_free()
	await get_tree().process_frame

	if not inv:
		return

	# Filter
	var items: Array = []
	for slot in inv.inventory:
		var item_data = ItemDatabase.get_item(slot["item_id"])
		var item_type = item_data.get("type", "")
		if _current_filter == "" or item_type == _current_filter:
			items.append(slot)

	# Sort
	if _sort_mode == 1:
		items.sort_custom(_sort_by_quality)
	elif _sort_mode == 2:
		items.sort_custom(_sort_by_name)

	for slot in items:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(60, 60)
		var item_data = ItemDatabase.get_item(slot["item_id"])
		btn.text = item_data.get("name", "?")
		btn.tooltip_text = slot["item_id"]

		if slot.has("count"):
			btn.text += "\n" + str(slot["count"])

		var quality = item_data.get("quality", "")
		if quality != "":
			btn.modulate = ItemDatabase.get_quality_color(quality)
		elif item_data.get("type", "") == "consumable":
			btn.modulate = Color(0.4, 1.0, 0.4, 1)

		# F1 quick-use indicator
		if slot["item_id"] == inv.quick_use_slot:
			var badge = Label.new()
			badge.text = "F1"
			badge.add_theme_font_size_override("font_size", 10)
			badge.modulate = Color(1.0, 0.85, 0.0)
			badge.position = Vector2(44, 2)
			btn.add_child(badge)

		btn.pressed.connect(_on_slot_pressed.bind(slot))
		grid.add_child(btn)

	detail_label.text = "背包 (%d/%d)" % [inv.inventory.size(), inv.MAX_INVENTORY_SIZE]
	_clear_action_row()

func _sort_by_quality(a: Dictionary, b: Dictionary) -> bool:
	var da = ItemDatabase.get_item(a["item_id"])
	var db = ItemDatabase.get_item(b["item_id"])
	var wa = QUALITY_WEIGHT.get(da.get("quality", "normal"), 0)
	var wb = QUALITY_WEIGHT.get(db.get("quality", "normal"), 0)
	return wa > wb

func _sort_by_name(a: Dictionary, b: Dictionary) -> bool:
	var da = ItemDatabase.get_item(a["item_id"])
	var db = ItemDatabase.get_item(b["item_id"])
	return da.get("name", "") < db.get("name", "")

func _on_slot_pressed(slot: Dictionary):
	var item_data = ItemDatabase.get_item(slot["item_id"])
	var item_id = slot["item_id"]
	_action_slot = slot
	_last_pressed_item_id = item_id

	var text = item_data.get("name", item_id)
	text += "\n类型: " + item_data.get("type", "未知")

	if item_data.get("type", "") == "equipment":
		text += "\n品质: " + item_data.get("quality", "普通")
		var slot_type = item_data.get("slot", "")
		var compare = _get_equipped_stats(slot_type)
		if item_data.get("attack", 0) > 0:
			text += "\n攻击: +" + str(item_data["attack"])
			if compare.has("attack"):
				text += _diff_str(item_data["attack"], compare["attack"])
		if item_data.get("defense", 0) > 0:
			text += "\n防御: +" + str(item_data["defense"])
			if compare.has("defense"):
				text += _diff_str(item_data["defense"], compare["defense"])
		if item_data.get("hp", 0) > 0:
			text += "\n生命: +" + str(item_data["hp"])
			if compare.has("hp"):
				text += _diff_str(item_data["hp"], compare["hp"])
		if item_data.get("crit_rate", 0) > 0:
			text += "\n暴击率: +" + str(int(item_data["crit_rate"] * 100)) + "%"
		if item_data.get("crit_damage", 0) > 0:
			text += "\n暴击伤害: +" + str(int(item_data["crit_damage"] * 100)) + "%"
	elif item_data.get("type", "") == "consumable":
		var eff = item_data.get("effect", "")
		var val = item_data.get("value", 0)
		match eff:
			"heal":
				if val < 0:
					text += "\n效果: 回复全部生命"
				else:
					text += "\n效果: 回复 %d 生命" % val
			"speed":
				text += "\n效果: 移速 +50%% 持续 %d 秒" % val
			"defense_buff":
				text += "\n效果: 防御 +%d 持续 30 秒" % val
			"attack_buff":
				text += "\n效果: 攻击 +%d 持续 30 秒" % val

	detail_label.text = text
	_show_action_row(item_data, slot)

func _show_action_row(item_data: Dictionary, slot: Dictionary):
	_clear_action_row()
	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 8)

	var item_type = item_data.get("type", "")

	if item_type == "equipment" and slot.has("uid"):
		var btn_equip = Button.new()
		btn_equip.text = "穿戴"
		btn_equip.pressed.connect(_do_equip.bind(slot["uid"]))
		_action_row.add_child(btn_equip)
	elif item_type == "consumable":
		var btn_use = Button.new()
		btn_use.text = "使用"
		btn_use.pressed.connect(_do_use.bind(slot["item_id"]))
		_action_row.add_child(btn_use)

		var btn_f1 = Button.new()
		btn_f1.text = "设为F1"
		btn_f1.pressed.connect(_do_set_f1.bind(slot["item_id"]))
		_action_row.add_child(btn_f1)

	# Drop button for all items
	var btn_drop = Button.new()
	btn_drop.text = "丢弃"
	btn_drop.pressed.connect(_do_drop.bind(slot))
	_action_row.add_child(btn_drop)

	$VBoxContainer.add_child(_action_row)

func _clear_action_row():
	if _action_row and is_instance_valid(_action_row):
		_action_row.queue_free()
		_action_row = null

func _do_equip(uid: String):
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		equip_sys.equip(uid)
	_refresh()

func _do_use(item_id: String):
	var sys = get_node_or_null("/root/InventorySystem")
	if sys:
		sys.use_item(item_id)
	_refresh()

func _do_set_f1(item_id: String):
	var sys = get_node_or_null("/root/InventorySystem")
	if sys:
		sys.set_quick_use(item_id)
	_refresh()

func _do_drop(slot: Dictionary):
	var sys = get_node_or_null("/root/InventorySystem")
	if sys:
		sys.remove_item(slot["item_id"], 1)
	_refresh()

func _get_equipped_stats(slot_type: String) -> Dictionary:
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if not equip_sys:
		return {}
	var equipped = equip_sys.get_equipped(slot_type)
	if not equipped:
		return {}
	var data = ItemDatabase.get_item(equipped["item_id"])
	var result = {}
	for stat in ["attack", "defense", "hp"]:
		if data.get(stat, 0) > 0:
			result[stat] = data[stat]
	return result

func _diff_str(new_val: int, old_val: int) -> String:
	var diff = new_val - old_val
	if diff > 0:
		return " (↑%d)" % diff
	elif diff < 0:
		return " (↓%d)" % abs(diff)
	return " (=)"

func _input(event):
	if event.is_action_pressed("inventory"):
		toggle()
	elif is_open and event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		if _last_pressed_item_id != "" and ItemDatabase.is_consumable(_last_pressed_item_id):
			var inv = get_node_or_null("/root/InventorySystem")
			if inv:
				inv.set_quick_use(_last_pressed_item_id)
				_refresh()
