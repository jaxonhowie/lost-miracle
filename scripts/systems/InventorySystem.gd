extends Node

signal inventory_changed
signal item_added(item_id: String, count: int)

# inventory: array of { "item_id": String, "count": int } for materials
#                       { "item_id": String, "uid": String } for equipment
var inventory: Array = []

func add_item(item_id: String, count: int = 1):
	if ItemDatabase.is_equipment(item_id):
		for i in count:
			var uid = "eq_%06d" % randi_range(0, 999999)
			inventory.append({"item_id": item_id, "uid": uid})
	else:
		# Stack with existing
		for slot in inventory:
			if slot["item_id"] == item_id and slot.has("count"):
				slot["count"] += count
				inventory_changed.emit()
				item_added.emit(item_id, count)
				return
		# New stack
		inventory.append({"item_id": item_id, "count": count})
	inventory_changed.emit()
	item_added.emit(item_id, count)

func remove_item(item_id: String, count: int = 1) -> bool:
	for i in range(inventory.size()):
		var slot = inventory[i]
		if slot["item_id"] == item_id:
			if slot.has("count"):
				if slot["count"] >= count:
					slot["count"] -= count
					if slot["count"] <= 0:
						inventory.remove_at(i)
					inventory_changed.emit()
					return true
			else:
				# Equipment — remove one instance
				inventory.remove_at(i)
				inventory_changed.emit()
				return true
	return false

func remove_by_uid(uid: String) -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("uid", "") == uid:
			inventory.remove_at(i)
			inventory_changed.emit()
			return true
	return false

func get_item_count(item_id: String) -> int:
	var total = 0
	for slot in inventory:
		if slot["item_id"] == item_id:
			total += slot.get("count", 1)
	return total

func has_item(item_id: String, count: int = 1) -> bool:
	return get_item_count(item_id) >= count

func get_equipment_by_uid(uid: String) -> Dictionary:
	for slot in inventory:
		if slot.get("uid", "") == uid:
			return slot
	return {}

func get_all_equipment() -> Array:
	var result = []
	for slot in inventory:
		if slot.has("uid"):
			result.append(slot)
	return result

func get_all_materials() -> Array:
	var result = []
	for slot in inventory:
		if slot.has("count"):
			result.append(slot)
	return result
