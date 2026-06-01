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
		var item_type = item_data.get("type", "")

		var vbox = VBoxContainer.new()

		var hbox = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = item_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item_data.has("quality"):
			name_label.modulate = ItemDatabase.get_quality_color(item_data["quality"])
		hbox.add_child(name_label)

		var price_label = Label.new()
		price_label.text = "%d G" % price
		price_label.modulate = Color(1.0, 0.85, 0.2)
		hbox.add_child(price_label)

		var buy_btn = Button.new()
		buy_btn.text = "购买"
		buy_btn.pressed.connect(_on_buy_pressed.bind(item_id))
		hbox.add_child(buy_btn)

		vbox.add_child(hbox)

		var detail_label = Label.new()
		detail_label.add_theme_font_size_override("font_size", 12)
		detail_label.modulate = Color(0.7, 0.7, 0.7)
		detail_label.text = _get_item_detail_text(item_data)
		if not detail_label.text.is_empty():
			vbox.add_child(detail_label)

		buy_list.add_child(vbox)

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
		AudioManager.play_sfx("res://assets/audio/sfx_buy.ogg")
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
		AudioManager.play_sfx("res://assets/audio/sfx_sell.ogg")
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

func _get_item_detail_text(item_data: Dictionary) -> String:
	var parts: PackedStringArray = []
	var item_type = item_data.get("type", "")
	var slot = item_data.get("slot", "")

	if item_type == "equipment":
		parts.append(_get_slot_name(slot))
		var atk = item_data.get("attack", 0)
		var def = item_data.get("defense", 0)
		var hp = item_data.get("hp", 0)
		if atk > 0:
			parts.append("攻击 +%d" % atk)
		if def > 0:
			parts.append("防御 +%d" % def)
		if hp > 0:
			parts.append("生命 +%d" % hp)
	elif item_type == "consumable":
		parts.append("消耗品")
		var effect = item_data.get("effect", "")
		var value = item_data.get("value", 0)
		match effect:
			"heal":
				parts.append("恢复 %d HP" % value)
			"speed":
				parts.append("移速 +%d%% %d秒" % [value, item_data.get("duration", 10)])
			"defense":
				parts.append("防御 +%d %d秒" % [value, item_data.get("duration", 10)])
			"attack":
				parts.append("攻击 +%d %d秒" % [value, item_data.get("duration", 10)])
	elif item_type == "material":
		parts.append("材料")

	return " | ".join(parts)

func _get_slot_name(slot: String) -> String:
	match slot:
		"weapon":
			return "武器"
		"armor":
			return "防具"
		"helmet":
			return "头盔"
		"boots":
			return "鞋子"
		"ring":
			return "戒指"
		"accessory":
			return "饰品"
		_:
			return "装备"
