extends Node

signal equipment_changed

# Equipment slots: { "slot_name": { uid, item_id, enhance_level } }
var equipped: Dictionary = {
	"weapon": null,
	"armor": null,
	"boots": null,
	"ring": null,
}

func equip(uid: String) -> bool:
	var inv = get_node_or_null("/root/InventorySystem")
	if not inv:
		return false

	# Find item in inventory by uid
	var slot_data = inv.get_by_uid(uid)
	if not slot_data:
		return false

	var item_id = slot_data["item_id"]
	var item_data = ItemDatabase.get_item(item_id)
	if item_data.get("type", "") != "equipment":
		return false

	var slot_name = item_data.get("slot", "")
	if slot_name == "" or not equipped.has(slot_name):
		return false

	# If something already equipped in that slot, unequip it first
	if equipped[slot_name] != null:
		unequip(slot_name)

	# Remove from inventory
	inv.remove_by_uid(uid)

	# Equip
	equipped[slot_name] = {
		"uid": uid,
		"item_id": item_id,
		"enhance_level": slot_data.get("enhance_level", 0),
	}

	equipment_changed.emit()
	return true

func unequip(slot_name: String) -> bool:
	if not equipped.has(slot_name) or equipped[slot_name] == null:
		return false

	var inv = get_node_or_null("/root/InventorySystem")
	if not inv:
		return false

	var equip_data = equipped[slot_name]
	equipped[slot_name] = null

	# Add back to inventory
	inv.add_equipment(equip_data["item_id"], equip_data["uid"], equip_data.get("enhance_level", 0))

	equipment_changed.emit()
	return true

func get_equipped(slot_name: String) -> Variant:
	return equipped.get(slot_name, null)

func get_total_stats() -> Dictionary:
	var stats = {
		"attack": 0,
		"defense": 0,
		"hp": 0,
		"crit_rate": 0.0,
		"crit_damage": 0.0,
	}

	for slot_name in equipped:
		var equip_data = equipped[slot_name]
		if equip_data == null:
			continue

		var item_data = ItemDatabase.get_item(equip_data["item_id"])
		if item_data.is_empty():
			continue

		var enhance_level = equip_data.get("enhance_level", 0)

		# Base stats
		var base_attack = item_data.get("attack", 0)
		var base_defense = item_data.get("defense", 0)
		var base_hp = item_data.get("hp", 0)

		# Enhancement bonus
		if slot_name == "weapon":
			base_attack = int(base_attack * (1.0 + enhance_level * 0.1))
		else:
			base_defense = int(base_defense * (1.0 + enhance_level * 0.08))
			base_hp = int(base_hp * (1.0 + enhance_level * 0.05))

		stats["attack"] += base_attack
		stats["defense"] += base_defense
		stats["hp"] += base_hp
		stats["crit_rate"] += item_data.get("crit_rate", 0.0)
		stats["crit_damage"] += item_data.get("crit_damage", 0.0)

	return stats
