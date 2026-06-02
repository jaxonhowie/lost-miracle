extends Node

signal shop_changed

var buy_items: Array = []
var sell_prices: Dictionary = {}
var _stock: Dictionary = {}  # { item_id: remaining_count } for limited items

func _ready():
	_load_shop_data()
	_reset_stock()

func _load_shop_data():
	var file = FileAccess.open("res://data/shop.json", FileAccess.READ)
	if not file:
		push_error("ShopSystem: cannot open shop.json")
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("ShopSystem: JSON parse error")
		return
	buy_items = json.data.get("buy_items", [])
	sell_prices = json.data.get("sell_prices", {})

func _reset_stock():
	_stock.clear()
	for entry in buy_items:
		if entry.has("stock"):
			_stock[entry["item_id"]] = entry["stock"]

func get_current_floor() -> int:
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	if spawn_sys:
		return spawn_sys.current_floor
	return 1

func get_available_items() -> Array:
	var current_floor = get_current_floor()
	var available: Array = []
	for entry in buy_items:
		var req_floor = entry.get("floor", 0)
		if current_floor >= req_floor:
			# Check stock
			var item_id = entry["item_id"]
			if _stock.has(item_id) and _stock[item_id] <= 0:
				continue
			available.append(entry)
	return available

func get_buy_price(item_id: String) -> int:
	for entry in buy_items:
		if entry["item_id"] == item_id:
			var base_price = entry["price"]
			# Apply honor discount
			var honor_sys = get_node_or_null("/root/HonorSystem")
			if honor_sys:
				var discount = honor_sys.get_shop_discount()
				if discount > 0:
					base_price = int(base_price * (1.0 - discount))
			return base_price
	return -1

func get_sell_price(item_id: String) -> int:
	if sell_prices.has(item_id):
		return sell_prices[item_id]
	# Equipment: sell for 30% of a rough base value
	var item_data = ItemDatabase.get_item(item_id)
	if item_data.get("type") == "equipment":
		var quality = item_data.get("quality", "normal")
		match quality:
			"normal": return 15
			"fine": return 40
			"rare": return 100
			"epic": return 250
	return 1

func buy_item(item_id: String) -> Dictionary:
	# Check honor trade restriction
	var honor_sys = get_node_or_null("/root/HonorSystem")
	if honor_sys and not honor_sys.can_trade():
		return {"success": false, "error": "honor_too_low"}

	# Check floor requirement
	var current_floor = get_current_floor()
	for entry in buy_items:
		if entry["item_id"] == item_id:
			if current_floor < entry.get("floor", 0):
				return {"success": false, "error": "floor_too_low"}
			break

	# Check stock
	if _stock.has(item_id) and _stock[item_id] <= 0:
		return {"success": false, "error": "out_of_stock"}

	var price = get_buy_price(item_id)
	if price < 0:
		return {"success": false, "error": "not_for_sale"}

	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return {"success": false, "error": "no_player"}
	var player = players[0]

	if player.gold < price:
		return {"success": false, "error": "no_gold"}

	var inv = get_node_or_null("/root/InventorySystem")
	if not inv:
		return {"success": false, "error": "no_inventory"}

	player.gold -= price
	inv.add_item(item_id, 1)

	# Reduce stock for limited items
	if _stock.has(item_id):
		_stock[item_id] -= 1

	shop_changed.emit()
	return {"success": true}

func sell_item(item_id: String, uid: String = "") -> Dictionary:
	var price = get_sell_price(item_id)
	var inv = get_node_or_null("/root/InventorySystem")
	if not inv:
		return {"success": false, "error": "no_inventory"}

	var removed = false
	if uid != "":
		removed = inv.remove_by_uid(uid)
	else:
		removed = inv.remove_item(item_id, 1)

	if not removed:
		return {"success": false, "error": "no_item"}

	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		players[0].gold += price
	shop_changed.emit()
	return {"success": true, "price": price}

func get_stock_remaining(item_id: String) -> int:
	return _stock.get(item_id, -1)  # -1 means unlimited
