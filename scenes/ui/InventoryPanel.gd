extends PanelContainer

var is_open: bool = false
var inv: Node

@onready var grid: GridContainer = $VBoxContainer/ScrollContainer/GridContainer
@onready var detail_label: Label = $VBoxContainer/DetailLabel

func _ready():
	visible = false
	inv = get_node_or_null("/root/InventorySystem")
	if inv:
		inv.inventory_changed.connect(_refresh)

func toggle():
	is_open = !is_open
	visible = is_open
	if is_open:
		_refresh()

func _refresh():
	# Clear grid
	for child in grid.get_children():
		child.queue_free()
	await get_tree().process_frame

	if not inv:
		return

	for slot in inv.inventory:
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

		btn.pressed.connect(_on_slot_pressed.bind(slot))
		grid.add_child(btn)

	detail_label.text = "背包 (%d)" % inv.inventory.size()

func _on_slot_pressed(slot: Dictionary):
	var item_data = ItemDatabase.get_item(slot["item_id"])
	var item_id = slot["item_id"]
	var text = item_data.get("name", item_id)
	text += "\n类型: " + item_data.get("type", "未知")

	if item_data.get("type", "") == "equipment":
		text += "\n品质: " + item_data.get("quality", "普通")
		if item_data.get("attack", 0) > 0:
			text += "\n攻击: +" + str(item_data["attack"])
		if item_data.get("defense", 0) > 0:
			text += "\n防御: +" + str(item_data["defense"])
		if item_data.get("hp", 0) > 0:
			text += "\n生命: +" + str(item_data["hp"])
		text += "\n\n点击穿戴"
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
		text += "\n\n点击使用 | Q设为F1"

	detail_label.text = text

	# Try to equip if it's equipment
	if item_data.get("type", "") == "equipment" and slot.has("uid"):
		var equip_sys = get_node_or_null("/root/EquipmentSystem")
		if equip_sys:
			equip_sys.equip(slot["uid"])
	# Use if consumable
	elif item_data.get("type", "") == "consumable":
		var sys = get_node_or_null("/root/InventorySystem")
		if sys:
			sys.use_item(item_id)

	# Store last pressed item_id for quick-use assignment
	_last_pressed_item_id = item_id

var _last_pressed_item_id: String = ""

func _input(event):
	if event.is_action_pressed("inventory"):
		toggle()
	elif is_open and event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		if _last_pressed_item_id != "" and ItemDatabase.is_consumable(_last_pressed_item_id):
			var inv = get_node_or_null("/root/InventorySystem")
			if inv:
				inv.set_quick_use(_last_pressed_item_id)
				detail_label.text += "\n[F1快捷槽已设置]"
