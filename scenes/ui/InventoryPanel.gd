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

func _input(event):
	if event.is_action_pressed("inventory"):
		toggle()

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

		btn.pressed.connect(_on_slot_pressed.bind(slot))
		grid.add_child(btn)

	detail_label.text = "背包 (%d)" % inv.inventory.size()

func _on_slot_pressed(slot: Dictionary):
	var item_data = ItemDatabase.get_item(slot["item_id"])
	var text = item_data.get("name", slot["item_id"])
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

	detail_label.text = text

	# Try to equip if it's equipment
	if item_data.get("type", "") == "equipment" and slot.has("uid"):
		var equip_sys = get_node_or_null("/root/EquipmentSystem")
		if equip_sys:
			equip_sys.equip(slot["uid"])
