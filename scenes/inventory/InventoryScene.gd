extends Control

## 背包场景

var selected_item: Dictionary = {}

func _ready() -> void:
	$Panel/Margin/VBox/Header/CloseBtn.pressed.connect(_on_close)
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EquipBtn.pressed.connect(_on_equip)
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/UnequipBtn.pressed.connect(_on_unequip)
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/DiscardBtn.pressed.connect(_on_discard)
	_refresh_ui()

func _refresh_ui() -> void:
	_refresh_equipped()
	_refresh_inventory()
	_refresh_stats()
	_clear_detail()

func _refresh_equipped() -> void:
	var slots = $Panel/Margin/VBox/Content/EquipmentPanel/EquipSlots
	for child in slots.get_children():
		child.queue_free()
	var slot_names = {
		"weapon": "武器", "helmet": "头盔", "armor": "胸甲",
		"gloves": "护手", "ring": "戒指", "necklace": "项链"
	}
	for slot_id in slot_names:
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.custom_minimum_size = Vector2(60, 0)
		label.text = slot_names[slot_id] + ":"
		hbox.add_child(label)
		var uid = PlayerData.equipped.get(slot_id, "")
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(150, 30)
		if uid.is_empty():
			btn.text = "空"
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			var eq = PlayerData.get_equipment_by_uid(uid)
			btn.text = eq.get("name", "未知")
			btn.modulate = Equipment.get_quality_color(eq.get("quality", "normal"))
		btn.pressed.connect(_on_equipped_slot_click.bind(slot_id))
		hbox.add_child(btn)
		slots.add_child(hbox)

func _refresh_inventory() -> void:
	var list = $Panel/Margin/VBox/Content/InventoryPanel/ItemList
	for child in list.get_children():
		child.queue_free()
	for item in PlayerData.inventory:
		var btn = Button.new()
		btn.text = item.get("name", "未知") + "  +" + str(int(item.get("enhance_level", 0)))
		btn.modulate = Equipment.get_quality_color(item.get("quality", "normal"))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_click.bind(item))
		list.add_child(btn)
	if PlayerData.inventory.is_empty():
		var label = Label.new()
		label.text = "背包为空"
		label.modulate = Color(0.5, 0.5, 0.5)
		list.add_child(label)

func _refresh_stats() -> void:
	var stats = PlayerData.get_final_stats()
	var ps = PlayerData.primary_stats
	var text = "STR: %d  AGI: %d  INT: %d%s\nHP: %d  MP: %d\n物攻: %d  魔攻: %d  远攻: %d\n防御: %d  魔防: %d  攻速: %.2f\n暴击率: %.0f%%  暴击伤害: %.0f%%\n吸血: %.0f%%  闪避: %.0f%%" % [
		ps["STR"], ps["AGI"], ps["INT"],
		"  [+%d点]" % PlayerData.unallocated_points if PlayerData.unallocated_points > 0 else "",
		int(stats["max_hp"]), int(stats["max_mp"]),
		int(stats["melee_atk"]), int(stats["magic_atk"]), int(stats["range_atk"]),
		int(stats["def"]), int(stats.get("mdef", 0)), stats["atk_spd"],
		stats["crit_rate"] * 100, stats["crit_dmg"] * 100,
		stats["lifesteal"] * 100, stats["dodge"] * 100
	]
	$Panel/Margin/VBox/StatsPanel/StatsText.text = text

func _clear_detail() -> void:
	selected_item = {}
	$Panel/Margin/VBox/Content/DetailPanel/DetailText.text = "选择一件物品查看详情"
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EquipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/UnequipBtn.visible = false

func _on_item_click(item: Dictionary) -> void:
	selected_item = item
	_show_item_detail(item, false)

func _on_equipped_slot_click(slot_id: String) -> void:
	var uid = PlayerData.equipped.get(slot_id, "")
	if uid.is_empty():
		return
	var eq = PlayerData.get_equipment_by_uid(uid)
	selected_item = eq
	_show_item_detail(eq, true)

func _show_item_detail(item: Dictionary, is_equipped: bool) -> void:
	var quality = item.get("quality", "normal")
	var text = "[color=#%s]%s[/color]\n" % [Equipment.QUALITY_COLORS.get(quality, Color.WHITE).to_html(false), item.get("name", "未知")]
	text += "品质: %s\n" % _quality_name(quality)
	text += "部位: %s\n" % _slot_name(item.get("slot", ""))
	text += "强化: +%d\n" % int(item.get("enhance_level", 0))
	text += "\n基础属性:\n"
	for key in item.get("base_stats", {}):
		text += "  %s: +%s\n" % [_stat_name(key), _format_stat_value(key, item["base_stats"][key])]
	text += "\n词条:\n"
	for affix in item.get("affixes", []):
		text += "  %s: +%s\n" % [_stat_name(affix.get("stat", "")), _format_stat_value(affix.get("stat", ""), affix.get("value", 0))]
	$Panel/Margin/VBox/Content/DetailPanel/DetailText.text = text
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EquipBtn.visible = not is_equipped
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/UnequipBtn.visible = is_equipped
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/DiscardBtn.visible = not is_equipped

func _on_equip() -> void:
	if selected_item.is_empty():
		return
	var uid = selected_item.get("uid", "")
	if uid.is_empty():
		return
	PlayerData.equip(uid)
	SaveManager.save_game()
	_refresh_ui()

func _on_unequip() -> void:
	if selected_item.is_empty():
		return
	var slot = selected_item.get("slot", "")
	PlayerData.unequip(slot)
	SaveManager.save_game()
	_refresh_ui()

func _on_discard() -> void:
	if selected_item.is_empty():
		return
	var uid = selected_item.get("uid", "")
	if uid.is_empty():
		return
	PlayerData.remove_from_inventory(uid)
	selected_item = {}
	SaveManager.save_game()
	_refresh_ui()

func _on_close() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")

func _quality_name(quality: String) -> String:
	match quality:
		"normal": return "普通"
		"fine": return "精良"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
	return quality

func _slot_name(slot: String) -> String:
	match slot:
		"weapon": return "武器"
		"helmet": return "头盔"
		"armor": return "胸甲"
		"gloves": return "护手"
		"ring": return "戒指"
		"necklace": return "项链"
	return slot

func _stat_name(stat: String) -> String:
	match stat:
		"atk": return "攻击力"
		"melee_atk": return "物理攻击"
		"range_atk": return "远程攻击"
		"magic_atk": return "魔法攻击"
		"atk_spd": return "攻击速度"
		"def": return "防御力"
		"mdef": return "魔法防御"
		"max_hp": return "生命值"
		"max_mp": return "魔法值"
		"spd": return "攻击速度"
		"crit_rate": return "暴击率"
		"crit_dmg": return "暴击伤害"
		"lifesteal": return "吸血"
		"dodge": return "闪避"
		"hit": return "命中"
		"STR": return "力量"
		"AGI": return "敏捷"
		"INT": return "智力"
		"skill_damage": return "技能伤害"
		"undead_damage": return "对亡灵增伤"
		"damage_reduce": return "受到伤害降低"
	return stat

func _format_stat_value(stat: String, value) -> String:
	# 百分比属性
	if stat in ["crit_rate", "crit_dmg", "lifesteal", "dodge", "hit", "skill_damage", "undead_damage", "damage_reduce"]:
		return "%.0f%%" % (value * 100)
	# 浮点属性
	if stat in ["atk_spd"]:
		return "%.2f" % value
	# 整数属性
	return str(int(value))
