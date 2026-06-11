extends Control

## 背包场景

var selected_item: Dictionary = {}
var current_page: int = 0
var items_per_page: int = 10
var total_pages: int = 1
var use_blessed_stone: bool = false
var showing_enhance: bool = false

func _ready() -> void:
	$Panel/Margin/VBox/Header/CloseBtn.pressed.connect(_on_close)
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EquipBtn.pressed.connect(_on_equip)
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/UnequipBtn.pressed.connect(_on_unequip)
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EnhanceBtn.pressed.connect(_on_enhance_toggle)
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/DiscardBtn.pressed.connect(_on_discard)
	$Panel/Margin/VBox/Content/InventoryPanel/Pagination/PrevBtn.pressed.connect(_on_prev_page)
	$Panel/Margin/VBox/Content/InventoryPanel/Pagination/NextBtn.pressed.connect(_on_next_page)
	$Panel/Margin/VBox/Content/DetailPanel/EnhancePanel/StoneSelect/StoneOption.item_selected.connect(_on_stone_changed)
	$Panel/Margin/VBox/Content/DetailPanel/EnhancePanel/ConfirmEnhanceBtn.pressed.connect(_on_enhance_confirm)
	$Panel/Margin/VBox/Content/DetailPanel/EnhancePanel/CancelEnhanceBtn.pressed.connect(_on_enhance_cancel)
	_init_stone_select()
	_refresh_ui()
	if get_meta("open_enhance", false):
		call_deferred("_try_open_enhance_panel")

func _init_stone_select() -> void:
	var option = $Panel/Margin/VBox/Content/DetailPanel/EnhancePanel/StoneSelect/StoneOption
	option.clear()
	option.add_item("普通强化石 (x%d)" % PlayerData.enhance_stone, 0)
	option.add_item("受祝福强化石 (x%d)" % PlayerData.blessed_enhance_stone, 1)

func _on_stone_changed(index: int) -> void:
	use_blessed_stone = (index == 1)
	_update_enhance_info()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_TAB:
				if showing_enhance:
					_on_enhance_cancel()
				else:
					_on_close()
				accept_event()
			KEY_LEFT:
				_on_prev_page()
				accept_event()
			KEY_RIGHT:
				_on_next_page()
				accept_event()

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
		"weapon": "武器", "helmet": "头盔", "armor": "胸甲", "legs": "护腿",
		"gloves": "护手", "ring": "戒指", "necklace": "项链",
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
			var enhance_level = int(eq.get("enhance_level", 0))
			var quality = Equipment.get_quality_by_enhance(enhance_level)
			btn.text = eq.get("name", "未知") + " +" + str(enhance_level)
			btn.modulate = Equipment.get_quality_color(quality)
		btn.pressed.connect(_on_equipped_slot_click.bind(slot_id))
		hbox.add_child(btn)
		slots.add_child(hbox)

func _refresh_inventory() -> void:
	var list = $Panel/Margin/VBox/Content/InventoryPanel/ItemList
	for child in list.get_children():
		child.queue_free()
	
	var total_items = PlayerData.inventory.size()
	if PlayerData.health_potion > 0:
		total_items += 1
	total_pages = maxi(1, ceili(float(total_items) / items_per_page))
	current_page = clampi(current_page, 0, total_pages - 1)
	
	var all_items := []
	if PlayerData.health_potion > 0:
		all_items.append({"type": "potion"})
	var equipped_uids := {}
	for slot in PlayerData.equipped:
		var uid = PlayerData.equipped[slot]
		if not uid.is_empty():
			equipped_uids[uid] = true
	for item in PlayerData.inventory:
		all_items.append({"type": "equip", "item": item, "equipped": equipped_uids.has(item.get("uid", ""))})
	
	var start = current_page * items_per_page
	var end = mini(start + items_per_page, all_items.size())
	
	if all_items.is_empty():
		var label = Label.new()
		label.text = "背包为空"
		label.modulate = Color(0.5, 0.5, 0.5)
		list.add_child(label)
	else:
		for i in range(start, end):
			var entry = all_items[i]
			if entry["type"] == "potion":
				var btn = Button.new()
				btn.text = "生命药水 x%d" % PlayerData.health_potion
				btn.modulate = Color(0.2, 0.8, 0.2)
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.pressed.connect(_on_potion_click)
				list.add_child(btn)
			else:
				var item = entry["item"]
				var is_equipped = entry["equipped"]
				var enhance_level = int(item.get("enhance_level", 0))
				var quality = Equipment.get_quality_by_enhance(enhance_level)
				var btn = Button.new()
				var prefix = "[装备中] " if is_equipped else ""
				btn.text = prefix + item.get("name", "未知") + "  +" + str(enhance_level)
				btn.modulate = Equipment.get_quality_color(quality)
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.pressed.connect(_on_item_click.bind(item))
				list.add_child(btn)
	
	_update_pagination()

func _update_pagination() -> void:
	var pagination = $Panel/Margin/VBox/Content/InventoryPanel/Pagination
	pagination.get_node("PageLabel").text = "%d / %d" % [current_page + 1, total_pages]
	pagination.get_node("PrevBtn").disabled = (current_page <= 0)
	pagination.get_node("NextBtn").disabled = (current_page >= total_pages - 1)
	pagination.visible = (total_pages > 1)

func _on_prev_page() -> void:
	if current_page > 0:
		current_page -= 1
		_refresh_inventory()

func _on_next_page() -> void:
	if current_page < total_pages - 1:
		current_page += 1
		_refresh_inventory()

func _on_potion_click() -> void:
	_hide_enhance_panel()
	$Panel/Margin/VBox/Content/DetailPanel/DetailText.text = "生命药水\n\n恢复 20 点生命值\n\n数量: %d" % PlayerData.health_potion
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EquipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/UnequipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EnhanceBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/DiscardBtn.visible = false

func _refresh_stats() -> void:
	var stats = PlayerData.get_final_stats()
	var ps = PlayerData.primary_stats
	var text = "STR: %d  AGI: %d  INT: %d\nHP: %d  MP: %d\n物攻: %d  魔攻: %d  远攻: %d\n防御: %d  魔防: %d  攻速: %.2f\n暴击率: %.0f%%  暴击伤害: %.0f%%\n吸血: %.0f%%  闪避: %.0f%%\n\n药水: %d  强化石: %d  受祝福: %d  金币: %d" % [
		ps["STR"], ps["AGI"], ps["INT"],
		int(stats["max_hp"]), int(stats["max_mp"]),
		int(stats["melee_atk"]), int(stats["magic_atk"]), int(stats["range_atk"]),
		int(stats["def"]), int(stats.get("mdef", 0)), stats["atk_spd"],
		stats["crit_rate"] * 100, stats["crit_dmg"] * 100,
		stats["lifesteal"] * 100, stats["dodge"] * 100,
		PlayerData.health_potion, PlayerData.enhance_stone, PlayerData.blessed_enhance_stone, PlayerData.gold
	]
	$Panel/Margin/VBox/StatsPanel/StatsText.text = text

func _clear_detail() -> void:
	selected_item = {}
	_hide_enhance_panel()
	$Panel/Margin/VBox/Content/DetailPanel/DetailText.text = "选择一件物品查看详情"
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EquipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/UnequipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EnhanceBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/DiscardBtn.visible = false

func _on_item_click(item: Dictionary) -> void:
	selected_item = item
	_hide_enhance_panel()
	var uid = item.get("uid", "")
	var is_equipped = false
	for slot in PlayerData.equipped:
		if PlayerData.equipped[slot] == uid:
			is_equipped = true
			break
	_show_item_detail(item, is_equipped)

func _on_equipped_slot_click(slot_id: String) -> void:
	var uid = PlayerData.equipped.get(slot_id, "")
	if uid.is_empty():
		return
	var eq = PlayerData.get_equipment_by_uid(uid)
	selected_item = eq
	_hide_enhance_panel()
	_show_item_detail(eq, true)

func _show_item_detail(item: Dictionary, is_equipped: bool) -> void:
	var enhance_level = int(item.get("enhance_level", 0))
	var quality = Equipment.get_quality_by_enhance(enhance_level)
	var quality_name = Equipment.get_quality_name(quality)
	var grade = item.get("grade", "normal")
	var grade_name = Equipment.get_grade_name(grade)
	var text = "[color=#%s]%s[/color]\n" % [Equipment.QUALITY_COLORS.get(quality, Color.WHITE).to_html(false), item.get("name", "未知")]
	text += "品阶: [color=#%s]%s[/color]  强化品质: %s  +%d\n" % [
		Equipment.get_grade_color(grade).to_html(false), grade_name, quality_name, enhance_level]
	if item.get("is_blessed", false):
		text += "[color=#ffdd44]★ 祝福装备[/color]\n"
	text += "部位: %s\n" % _slot_name(item.get("slot", ""))
	var class_req = item.get("class_req", "")
	if class_req != null and class_req != "":
		var player_class = Game.get_player_class()
		if class_req == player_class:
			text += "职业: %s\n" % _class_name(class_req)
		else:
			text += "职业: [color=red]%s[/color]\n" % _class_name(class_req)
	text += "\n属性:\n"
	for key in item.get("base_stats", {}):
		var base_val = item["base_stats"][key]
		var effective_val = Equipment.calc_effective_stat_value(item, key)
		if effective_val == null:
			effective_val = base_val
		if effective_val != base_val:
			text += "  %s: +%s (基础 +%s)\n" % [
				_stat_name(key),
				_format_stat_value(key, effective_val),
				_format_stat_value(key, base_val),
			]
		else:
			text += "  %s: +%s\n" % [_stat_name(key), _format_stat_value(key, effective_val)]
	var affixes: Array = item.get("affixes", [])
	if not affixes.is_empty():
		text += "\n词条:\n"
		for affix in affixes:
			text += "  %s: +%s\n" % [
				affix.get("name", affix.get("stat", "")),
				_format_stat_value(affix.get("stat", ""), affix.get("value", 0)),
			]
	var active_effects = Equipment.get_active_effects(item)
	if not active_effects.is_empty():
		text += "\n特效:\n"
		for effect_key in active_effects:
			var effect_val = active_effects[effect_key]
			if effect_val is bool:
				continue
			text += "  %s: +%s\n" % [_stat_name(effect_key), _format_stat_value(effect_key, effect_val)]
	$Panel/Margin/VBox/Content/DetailPanel/DetailText.text = text
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EquipBtn.visible = not is_equipped
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/UnequipBtn.visible = is_equipped
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/EnhanceBtn.visible = true
	$Panel/Margin/VBox/Content/DetailPanel/ActionButtons/DiscardBtn.visible = not is_equipped

# ========== 强化系统 ==========

func _try_open_enhance_panel() -> void:
	for eq in PlayerData.inventory:
		selected_item = eq
		_show_item_detail(eq, _is_equipped(eq.get("uid", "")))
		_show_enhance_panel()
		return

func _is_equipped(uid: String) -> bool:
	for slot in PlayerData.equipped:
		if PlayerData.equipped[slot] == uid:
			return true
	return false

func _on_enhance_toggle() -> void:
	if showing_enhance:
		_hide_enhance_panel()
	else:
		_show_enhance_panel()

func _show_enhance_panel() -> void:
	if selected_item.is_empty():
		return
	showing_enhance = true
	_init_stone_select()
	_update_enhance_info()
	$Panel/Margin/VBox/Content/DetailPanel/EnhancePanel.visible = true

func _hide_enhance_panel() -> void:
	showing_enhance = false
	$Panel/Margin/VBox/Content/DetailPanel/EnhancePanel.visible = false

func _update_enhance_info() -> void:
	if selected_item.is_empty():
		return
	var level = int(selected_item.get("enhance_level", 0))
	var info = $Panel/Margin/VBox/Content/DetailPanel/EnhancePanel/EnhanceInfo
	
	if level >= Equipment.MAX_ENHANCE_LEVEL:
		info.text = "[color=yellow]已达最高强化等级！[/color]"
		$Panel/Margin/VBox/Content/DetailPanel/EnhancePanel/ConfirmEnhanceBtn.disabled = true
		return
	
	var rates = Equipment.ENHANCE_RATES[level]
	var rate = rates[1] if use_blessed_stone else rates[0]
	var cost = Equipment.ENHANCE_COSTS[level]
	var stone_count = PlayerData.blessed_enhance_stone if use_blessed_stone else PlayerData.enhance_stone
	var can_afford = PlayerData.gold >= cost and stone_count >= 1
	
	var text = "当前强化: +%d\n" % level
	text += "成功率: [color=yellow]%.0f%%[/color]\n" % (rate * 100)
	text += "金币消耗: %d\n" % cost
	
	# 显示强化后属性变化
	for key in selected_item.get("base_stats", {}):
		var current_val = Equipment.calc_effective_stat_value(selected_item, key, level)
		var next_val = Equipment.calc_effective_stat_value(selected_item, key, level + 1)
		if current_val == null or next_val == null:
			continue
		if next_val > current_val:
			text += "%s: %s → %s (+%s)\n" % [
				_stat_name(key),
				_format_stat_value(key, current_val),
				_format_stat_value(key, next_val),
				_format_stat_value(key, next_val - current_val),
			]
	
	# 品质变化
	var current_quality = Equipment.get_quality_by_enhance(level)
	var next_quality = Equipment.get_quality_by_enhance(level + 1)
	if next_quality != current_quality:
		text += "\n[color=#%s]品质提升: %s → %s[/color]" % [
			Equipment.QUALITY_COLORS.get(next_quality, Color.WHITE).to_html(false),
			Equipment.get_quality_name(current_quality),
			Equipment.get_quality_name(next_quality)
		]
	var risk_text = Equipment.get_break_risk_text(selected_item, use_blessed_stone)
	if not risk_text.is_empty():
		text += "\n[color=orange]%s[/color]" % risk_text
	
	info.text = text
	$Panel/Margin/VBox/Content/DetailPanel/EnhancePanel/ConfirmEnhanceBtn.disabled = not can_afford
	if not can_afford:
		info.text += "\n[color=red]材料不足！[/color]"

func _on_enhance_confirm() -> void:
	if selected_item.is_empty():
		return
	var level = int(selected_item.get("enhance_level", 0))
	if level >= Equipment.MAX_ENHANCE_LEVEL:
		return
	
	var cost = Equipment.ENHANCE_COSTS[level]
	if use_blessed_stone:
		if PlayerData.blessed_enhance_stone < 1:
			return
		PlayerData.blessed_enhance_stone -= 1
	else:
		if PlayerData.enhance_stone < 1:
			return
		PlayerData.enhance_stone -= 1
	PlayerData.gold -= cost
	
	var uid = selected_item.get("uid", "")
	var result = Equipment.roll_enhance(selected_item, use_blessed_stone)
	var result_color = Color.GREEN if result.get("success", false) else Color.RED
	if result.get("broken", false):
		result_color = Color(1.0, 0.3, 0.1)
		PlayerData.destroy_equipment(uid)
		selected_item = {}
		_hide_enhance_panel()
		_clear_detail()
	_show_enhance_result(result.get("message", ""), result_color)
	
	SaveManager.save_game()
	_init_stone_select()
	if not selected_item.is_empty():
		_update_enhance_info()
		var is_equipped = false
		for slot in PlayerData.equipped:
			if PlayerData.equipped[slot] == uid:
				is_equipped = true
				break
		_show_item_detail(selected_item, is_equipped)
	_refresh_equipped()
	_refresh_inventory()
	_refresh_stats()

func _show_enhance_result(text: String, color: Color) -> void:
	var info = $Panel/Margin/VBox/Content/DetailPanel/EnhancePanel/EnhanceInfo
	info.text += "\n[color=#%s]%s[/color]" % [color.to_html(false), text]

func _on_enhance_cancel() -> void:
	_hide_enhance_panel()

# ========== 其他操作 ==========

func _on_equip() -> void:
	if selected_item.is_empty():
		return
	var uid = selected_item.get("uid", "")
	if uid.is_empty():
		return
	var class_req = selected_item.get("class_req", "")
	if class_req != null and class_req != "":
		var player_class = Game.get_player_class()
		if class_req != player_class:
			_show_alert("装备职业不匹配！")
			return
	PlayerData.equip(uid)
	SaveManager.save_game()
	_refresh_ui()

func _show_alert(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "提示"
	dialog.dialog_text = message
	dialog.size = Vector2(250, 100)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

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
	for slot in PlayerData.equipped:
		if PlayerData.equipped[slot] == uid:
			return
	PlayerData.remove_from_inventory(uid)
	selected_item = {}
	SaveManager.save_game()
	_refresh_ui()

func _on_close() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")

func _slot_name(slot: String) -> String:
	match slot:
		"weapon": return "武器"
		"helmet": return "头盔"
		"armor": return "胸甲"
		"legs": return "护腿"
		"gloves": return "护手"
		"ring": return "戒指"
		"necklace": return "项链"
	return slot

func _class_name(cls: String) -> String:
	match cls:
		"warrior": return "战士"
		"ranger": return "游侠"
		"assassin": return "刺客"
		"elven": return "精灵"
	return cls

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
	if stat in ["crit_rate", "crit_dmg", "lifesteal", "dodge", "hit", "skill_damage", "undead_damage", "damage_reduce"]:
		return "%.0f%%" % (value * 100)
	if stat in ["atk_spd"]:
		return "%.2f" % value
	return str(int(value))
