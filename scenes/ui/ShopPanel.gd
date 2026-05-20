extends PanelContainer

var is_open: bool = false
var near_merchant: bool = false
var shop_sys: Node
var inv: Node

@onready var gold_label: Label = $VBoxContainer/GoldLabel
@onready var tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var buy_list: VBoxContainer = $VBoxContainer/TabContainer/Buy/VBoxContainer
@onready var sell_list: VBoxContainer = $VBoxContainer/TabContainer/Sell/VBoxContainer
@onready var result_label: Label = $VBoxContainer/ResultLabel

func _ready():
	visible = false
	shop_sys = get_node_or_null("/root/ShopSystem")
	inv = get_node_or_null("/root/InventorySystem")
	if shop_sys:
		shop_sys.shop_changed.connect(_refresh)
	if inv:
		inv.inventory_changed.connect(_refresh_sell_tab)

func toggle():
	is_open = !is_open
	visible = is_open
	if is_open:
		_refresh()

func _refresh():
	_refresh_gold()
	_refresh_buy_tab()
	_refresh_sell_tab()

func _refresh_gold():
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		gold_label.text = "金币: %d" % players[0].gold

func _refresh_buy_tab():
	for child in buy_list.get_children():
		child.queue_free()
	await get_tree().process_frame

	if not shop_sys:
		return

	for entry in shop_sys.buy_items:
		var item_id = entry["item_id"]
		var price = entry["price"]
		var item_data = ItemDatabase.get_item(item_id)
		var item_name = item_data.get("name", item_id)

		var hbox = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = item_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)

		var price_label = Label.new()
		price_label.text = "%d G" % price
		price_label.modulate = Color(1.0, 0.85, 0.2)
		hbox.add_child(price_label)

		var buy_btn = Button.new()
		buy_btn.text = "购买"
		buy_btn.pressed.connect(_on_buy_pressed.bind(item_id))
		hbox.add_child(buy_btn)

		buy_list.add_child(hbox)

func _refresh_sell_tab():
	for child in sell_list.get_children():
		child.queue_free()
	await get_tree().process_frame

	if not inv or not shop_sys:
		return

	# Show materials
	for slot in inv.inventory:
		if not slot.has("count"):
			continue
		var item_id = slot["item_id"]
		if item_id == "gold":
			continue
		var item_data = ItemDatabase.get_item(item_id)
		var item_name = item_data.get("name", item_id)
		var count = slot["count"]
		var sell_price = shop_sys.get_sell_price(item_id)

		var hbox = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = "%s x%d" % [item_name, count]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)

		var price_label = Label.new()
		price_label.text = "%d G" % sell_price
		price_label.modulate = Color(0.8, 0.9, 0.4)
		hbox.add_child(price_label)

		var sell_btn = Button.new()
		sell_btn.text = "出售"
		sell_btn.pressed.connect(_on_sell_pressed.bind(item_id, ""))
		hbox.add_child(sell_btn)

		sell_list.add_child(hbox)

	# Show equipment
	for slot in inv.inventory:
		if not slot.has("uid"):
			continue
		var item_id = slot["item_id"]
		var item_data = ItemDatabase.get_item(item_id)
		var item_name = item_data.get("name", item_id)
		var level = slot.get("enhance_level", 0)
		var display_name = item_name
		if level > 0:
			display_name += " +" + str(level)
		var sell_price = shop_sys.get_sell_price(item_id)

		var hbox = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var quality = item_data.get("quality", "normal")
		name_label.modulate = ItemDatabase.get_quality_color(quality)
		hbox.add_child(name_label)

		var price_label = Label.new()
		price_label.text = "%d G" % sell_price
		price_label.modulate = Color(0.8, 0.9, 0.4)
		hbox.add_child(price_label)

		var sell_btn = Button.new()
		sell_btn.text = "出售"
		sell_btn.pressed.connect(_on_sell_pressed.bind(item_id, slot["uid"]))
		hbox.add_child(sell_btn)

		sell_list.add_child(hbox)

	if inv.inventory.is_empty():
		var empty_label = Label.new()
		empty_label.text = "背包为空"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sell_list.add_child(empty_label)

func _on_buy_pressed(item_id: String):
	if not shop_sys:
		return
	var result = shop_sys.buy_item(item_id)
	if result["success"]:
		var item_data = ItemDatabase.get_item(item_id)
		result_label.text = "购买了 %s" % item_data.get("name", item_id)
		result_label.modulate = Color.GREEN
	else:
		match result.get("error", ""):
			"no_gold":
				result_label.text = "金币不足!"
			_:
				result_label.text = "购买失败!"
		result_label.modulate = Color.RED
	_refresh_gold()
	_clear_result()

func _on_sell_pressed(item_id: String, uid: String):
	if not shop_sys:
		return
	var result = shop_sys.sell_item(item_id, uid)
	if result["success"]:
		var item_data = ItemDatabase.get_item(item_id)
		result_label.text = "出售了 %s (+%d G)" % [item_data.get("name", item_id), result["price"]]
		result_label.modulate = Color.GREEN
	else:
		result_label.text = "出售失败!"
		result_label.modulate = Color.RED
	_refresh_gold()
	_clear_result()

func _clear_result():
	await get_tree().create_timer(2.0).timeout
	result_label.text = ""
	result_label.modulate = Color.WHITE
