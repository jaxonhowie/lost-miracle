extends Node

signal enhance_result(uid: String, success: bool, new_level: int)

# Success rates per level
const SUCCESS_RATES: Array[float] = [
	1.0,   # +0 -> +1
	0.95,  # +1 -> +2
	0.90,  # +2 -> +3
	0.80,  # +3 -> +4
	0.70,  # +4 -> +5
	0.60,  # +5 -> +6
	0.50,  # +6 -> +7
	0.40,  # +7 -> +8
	0.30,  # +8 -> +9
	0.20,  # +9 -> +10
]

const MAX_LEVEL: int = 10

# Returns { success_rate, stone_id, stone_count, use_core, core_count }
func get_enhance_info(uid: String) -> Dictionary:
	var inv = get_node_or_null("/root/InventorySystem")
	if not inv:
		return {}

	var slot_data = inv.get_by_uid(uid)
	if slot_data.is_empty():
		return {}

	var item_data = ItemDatabase.get_item(slot_data["item_id"])
	if not item_data.get("enhanceable", false):
		return {}

	var current_level = slot_data.get("enhance_level", 0)
	if current_level >= MAX_LEVEL:
		return { "max_level": true }

	var stone_id: String
	var stone_count: int = 1

	if current_level < 5:
		stone_id = "enhance_stone"
	elif current_level < 8:
		stone_id = "mid_enhance_stone"
	else:
		stone_id = "high_enhance_stone"

	var has_stone = inv.get_item_count(stone_id) >= stone_count
	var has_core = inv.get_item_count("boss_enhance_core") >= 1
	var rate = SUCCESS_RATES[current_level]

	# Boss core adds 20% success rate
	var bonus_rate = 0.0
	if has_core:
		bonus_rate = 0.2

	return {
		"max_level": false,
		"current_level": current_level,
		"success_rate": rate,
		"bonus_rate": bonus_rate,
		"final_rate": minf(rate + bonus_rate, 1.0),
		"stone_id": stone_id,
		"stone_count": stone_count,
		"has_stone": has_stone,
		"use_core": has_core,
		"core_count": 1,
	}

func try_enhance(uid: String, use_core: bool = false) -> Dictionary:
	var inv = get_node_or_null("/root/InventorySystem")
	if not inv:
		return { "success": false, "error": "no_inventory" }

	var info = get_enhance_info(uid)
	if info.get("max_level", false):
		return { "success": false, "error": "max_level" }

	if not info.get("has_stone", false):
		return { "success": false, "error": "no_stone" }

	# Consume stone
	inv.remove_item(info["stone_id"], info["stone_count"])

	# Consume core if used
	var core_used = false
	if use_core and info.get("use_core", false):
		inv.remove_item("boss_enhance_core", 1)
		core_used = true

	# Roll success
	var rate = info["success_rate"]
	if core_used:
		rate = minf(rate + info["bonus_rate"], 1.0)

	var roll = randf()
	var success = roll < rate

	var current_level = info["current_level"]
	var new_level = current_level

	if success:
		new_level = current_level + 1
		# Update equipment level in inventory
		_update_equipment_level(uid, new_level)
	else:
		# Failure: downgrade rules
		if current_level >= 6:
			# +6 to +10: downgrade by 1
			new_level = current_level - 1
			_update_equipment_level(uid, new_level)

	enhance_result.emit(uid, success, new_level)

	return {
		"success": success,
		"old_level": current_level,
		"new_level": new_level,
		"rate": rate,
		"core_used": core_used,
	}

func _update_equipment_level(uid: String, level: int):
	var inv = get_node_or_null("/root/InventorySystem")
	if not inv:
		return

	for i in range(inv.inventory.size()):
		if inv.inventory[i].get("uid", "") == uid:
			inv.inventory[i]["enhance_level"] = level
			inv.inventory_changed.emit()
			break

	# Also update equipped item if it's currently worn
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		for slot_name in equip_sys.equipped:
			var equip_data = equip_sys.equipped[slot_name]
			if equip_data and equip_data.get("uid", "") == uid:
				equip_data["enhance_level"] = level
				equip_sys.equipment_changed.emit()
				break
