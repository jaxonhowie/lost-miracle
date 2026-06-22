extends Control

## 背包场景

var selected_item: Dictionary = {}
var current_page: int = 0
var items_per_page: int = 10
const ITEM_ROW_HEIGHT := 31
const ITEM_LIST_SEPARATION := 2
const INNER_PANEL_PADDING := 12
const INV_TITLE_BLOCK := 27
const TAB_BAR_HEIGHT := 28
const PAGINATION_HEIGHT := 34
const COLUMN_STYLE_MARGIN := 18
const INV_VBOX_SEPARATIONS := 24
var total_pages: int = 1
var use_blessed_stone: bool = false
var showing_enhance: bool = false
var inventory_tab: String = "all"

const INVENTORY_TABS := {
	"all": "TabAll",
	"weapon": "TabWeapon",
	"armor": "TabArmor",
	"jewelry": "TabJewelry",
	"consumable": "TabConsumable",
}

func _ready() -> void:
	$Panel/Margin/VBox/Header/CloseBtn.pressed.connect(_on_close)
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EquipBtn.pressed.connect(_on_equip)
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/UnequipBtn.pressed.connect(_on_unequip)
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EnhanceBtn.pressed.connect(_on_enhance_toggle)
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/DiscardBtn.pressed.connect(_on_discard)
	$Panel/Margin/VBox/Content/InventoryPanel/InvVBox/Pagination/PrevBtn.pressed.connect(_on_prev_page)
	$Panel/Margin/VBox/Content/InventoryPanel/InvVBox/Pagination/NextBtn.pressed.connect(_on_next_page)
	$EnhanceOverlay/Center/Dialog/Margin/VBox/StoneSelect/StoneOption.item_selected.connect(_on_stone_changed)
	$EnhanceOverlay/Center/Dialog/Margin/VBox/BtnRow/ConfirmEnhanceBtn.pressed.connect(_on_enhance_confirm)
	$EnhanceOverlay/Center/Dialog/Margin/VBox/BtnRow/CancelEnhanceBtn.pressed.connect(_on_enhance_cancel)
	$EnhanceOverlay/Dim.gui_input.connect(_on_enhance_dim_input)
	for tab_id in INVENTORY_TABS:
		var btn: Button = $Panel/Margin/VBox/Content/InventoryPanel/InvVBox/TabBar.get_node(INVENTORY_TABS[tab_id])
		btn.pressed.connect(_on_inventory_tab.bind(tab_id))
	_init_stone_select()
	_lock_content_layout()
	_refresh_ui()
	if get_meta("open_enhance", false):
		call_deferred("_try_open_enhance_panel")

func _init_stone_select() -> void:
	var option = $EnhanceOverlay/Center/Dialog/Margin/VBox/StoneSelect/StoneOption
	option.clear()
	var is_jewelry = not selected_item.is_empty() and Equipment.is_jewelry(selected_item)
	if is_jewelry:
		option.add_item("首饰强化石 (x%d)" % PlayerData.jewelry_enhance_stone, 0)
		option.add_item("受祝福首饰强化石 (x%d)" % PlayerData.blessed_jewelry_enhance_stone, 1)
	else:
		option.add_item("普通强化石 (x%d)" % PlayerData.enhance_stone, 0)
		option.add_item("受祝福强化石 (x%d)" % PlayerData.blessed_enhance_stone, 1)
	use_blessed_stone = false
	if option.item_count > 0:
		option.select(0)

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
	var slots = $Panel/Margin/VBox/Content/EquipmentPanel/EquipVBox/EquipSlotsFrame/EquipSlots
	for child in slots.get_children():
		child.queue_free()
	var slot_names = {
		"weapon": "武器", "helmet": "头盔", "armor": "胸甲", "legs": "护腿",
		"gloves": "护手", "ring_left": "左戒", "ring_right": "右戒", "necklace": "项链",
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
			btn.text = eq.get("name", "未知") + " +" + str(enhance_level)
			btn.modulate = Equipment.get_name_color(eq)
		btn.pressed.connect(_on_equipped_slot_click.bind(slot_id))
		hbox.add_child(btn)
		slots.add_child(hbox)

func _refresh_inventory() -> void:
	var list = $Panel/Margin/VBox/Content/InventoryPanel/InvVBox/ItemListFrame/InnerPanel/ItemList
	for child in list.get_children():
		child.queue_free()

	_update_tab_styles()
	var all_items := _build_inventory_entries()
	all_items = _filter_inventory_entries(all_items, inventory_tab)
	all_items = _sort_inventory_entries(all_items, inventory_tab)

	var total_items = all_items.size()
	total_pages = maxi(1, ceili(float(total_items) / items_per_page))
	current_page = clampi(current_page, 0, total_pages - 1)

	var start = current_page * items_per_page
	var end = mini(start + items_per_page, all_items.size())

	var page_entries: Array = []
	for i in range(start, end):
		page_entries.append(all_items[i])
	while page_entries.size() < items_per_page:
		page_entries.append(null)

	for i in range(items_per_page):
		var entry = page_entries[i]
		if all_items.is_empty() and i == 0:
			var empty_label = Label.new()
			empty_label.text = "背包为空" if inventory_tab == "all" else "该分类暂无物品"
			empty_label.modulate = Color(0.5, 0.5, 0.5)
			empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			list.add_child(_wrap_item_row(empty_label))
		elif entry == null:
			list.add_child(_make_item_row_spacer())
		elif entry["type"] == "potion":
			var btn = Button.new()
			btn.text = "生命药水 x%d" % PlayerData.health_potion
			btn.modulate = Color(0.2, 0.8, 0.2)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.flat = true
			btn.pressed.connect(_on_potion_click)
			list.add_child(_wrap_item_row(btn))
		elif entry["type"] == "stone":
			var btn = Button.new()
			btn.text = "%s x%d" % [entry["stone_name"], entry["stone_count"]]
			btn.modulate = Color(0.7, 0.6, 1.0)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.flat = true
			btn.pressed.connect(_on_stone_click.bind(entry))
			list.add_child(_wrap_item_row(btn))
		else:
			var item = entry["item"]
			var is_equipped = entry["equipped"]
			var enhance_level = int(item.get("enhance_level", 0))
			var btn = Button.new()
			var prefix = "[装备中] " if is_equipped else ""
			btn.text = prefix + item.get("name", "未知") + "  +" + str(enhance_level)
			btn.modulate = Equipment.get_name_color(item)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.flat = true
			btn.pressed.connect(_on_item_click.bind(item))
			list.add_child(_wrap_item_row(btn))

	_lock_content_layout()
	_update_pagination()

func _get_item_list_content_height() -> int:
	return items_per_page * ITEM_ROW_HEIGHT + (items_per_page - 1) * ITEM_LIST_SEPARATION

func _get_item_list_frame_height() -> int:
	return _get_item_list_content_height() + INNER_PANEL_PADDING

func _get_column_panel_height() -> int:
	return INV_TITLE_BLOCK + TAB_BAR_HEIGHT + _get_item_list_frame_height() + PAGINATION_HEIGHT + INV_VBOX_SEPARATIONS + COLUMN_STYLE_MARGIN

func _lock_content_layout() -> void:
	var content: Control = $Panel/Margin/VBox/Content
	var column_h := _get_column_panel_height()
	content.custom_minimum_size = Vector2(0, column_h)
	var frame: Control = $Panel/Margin/VBox/Content/InventoryPanel/InvVBox/ItemListFrame
	var frame_h := _get_item_list_frame_height()
	frame.custom_minimum_size = Vector2(0, frame_h)
	frame.size = Vector2(maxf(frame.size.x, 1.0), frame_h)

func _wrap_item_row(control: Control) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, ITEM_ROW_HEIGHT)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.clip_contents = true
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(control)
	return row

func _make_item_row_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, ITEM_ROW_HEIGHT)
	spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	spacer.clip_contents = true
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _on_inventory_tab(tab_id: String) -> void:
	if inventory_tab == tab_id:
		return
	inventory_tab = tab_id
	current_page = 0
	_refresh_inventory()

func _update_tab_styles() -> void:
	for tab_id in INVENTORY_TABS:
		var btn: Button = $Panel/Margin/VBox/Content/InventoryPanel/InvVBox/TabBar.get_node(INVENTORY_TABS[tab_id])
		if tab_id == inventory_tab:
			btn.modulate = Color(1.0, 0.92, 0.55)
		else:
			btn.modulate = Color(0.75, 0.75, 0.8)

func _build_inventory_entries() -> Array:
	var entries := []
	var equipped_uids := {}
	for slot in PlayerData.equipped:
		var uid = PlayerData.equipped[slot]
		if not uid.is_empty():
			equipped_uids[uid] = true
	if PlayerData.health_potion > 0:
		entries.append({"type": "potion"})
	var stone_types := [
		{"key": "enhance_stone", "name": "强化石", "count": PlayerData.enhance_stone},
		{"key": "blessed_enhance_stone", "name": "受祝福强化石", "count": PlayerData.blessed_enhance_stone},
		{"key": "jewelry_enhance_stone", "name": "首饰强化石", "count": PlayerData.jewelry_enhance_stone},
		{"key": "blessed_jewelry_enhance_stone", "name": "受祝福首饰强化石", "count": PlayerData.blessed_jewelry_enhance_stone},
	]
	for s in stone_types:
		if s["count"] > 0:
			entries.append({"type": "stone", "stone_key": s["key"], "stone_name": s["name"], "stone_count": s["count"]})
	for item in PlayerData.inventory:
		entries.append({
			"type": "equip",
			"item": item,
			"equipped": equipped_uids.has(item.get("uid", "")),
		})
	return entries

func _filter_inventory_entries(entries: Array, tab_id: String) -> Array:
	if tab_id == "all":
		return entries
	return entries.filter(func(entry): return _entry_matches_tab(entry, tab_id))

func _entry_matches_tab(entry: Dictionary, tab_id: String) -> bool:
	match tab_id:
		"consumable":
			return entry.get("type", "") in ["potion", "stone"]
		"weapon", "armor", "jewelry":
			if entry.get("type", "") != "equip":
				return false
			return _get_equip_category(entry.get("item", {})) == tab_id
	return true

func _get_equip_category(item: Dictionary) -> String:
	if Equipment.is_jewelry(item):
		return "jewelry"
	var slot = item.get("slot", "")
	if slot == "weapon":
		return "weapon"
	if slot in ["helmet", "armor", "legs", "gloves"]:
		return "armor"
	if slot == "necklace":
		return "jewelry"
	return "other"

func _sort_inventory_entries(entries: Array, tab_id: String) -> Array:
	var consumables: Array = []
	var equips: Array = []
	for entry in entries:
		if entry.get("type", "") in ["potion", "stone"]:
			consumables.append(entry)
		else:
			equips.append(entry)
	equips.sort_custom(func(a, b):
		var item_a: Dictionary = a.get("item", {})
		var item_b: Dictionary = b.get("item", {})
		var eq_a = a.get("equipped", false)
		var eq_b = b.get("equipped", false)
		if eq_a != eq_b:
			return eq_a and not eq_b
		var level_a = int(item_a.get("enhance_level", 0))
		var level_b = int(item_b.get("enhance_level", 0))
		if level_a != level_b:
			return level_a > level_b
		var blessed_a = item_a.get("is_blessed", false)
		var blessed_b = item_b.get("is_blessed", false)
		if blessed_a != blessed_b:
			return blessed_a and not blessed_b
		return str(item_a.get("name", "")) < str(item_b.get("name", ""))
	)
	if tab_id == "consumable":
		return consumables
	if tab_id == "all" and not consumables.is_empty():
		return consumables + equips
	return equips

func _update_pagination() -> void:
	var pagination = $Panel/Margin/VBox/Content/InventoryPanel/InvVBox/Pagination
	pagination.get_node("PageLabel").text = "%d / %d" % [current_page + 1, total_pages]
	pagination.get_node("PrevBtn").disabled = (current_page <= 0)
	pagination.get_node("NextBtn").disabled = (current_page >= total_pages - 1)

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
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/DetailTextFrame/DetailText.text = "生命药水\n\n恢复 20 点生命值\n\n数量: %d" % PlayerData.health_potion
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EquipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/UnequipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EnhanceBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/DiscardBtn.visible = false

func _on_stone_click(entry: Dictionary) -> void:
	_hide_enhance_panel()
	var desc := ""
	match entry.get("stone_key", ""):
		"enhance_stone":
			desc = "强化石\n\n用于强化武器和防具\n\n数量: %d" % PlayerData.enhance_stone
		"blessed_enhance_stone":
			desc = "受祝福强化石\n\n强化成功率更高，失败有概率保留装备\n\n数量: %d" % PlayerData.blessed_enhance_stone
		"jewelry_enhance_stone":
			desc = "首饰强化石\n\n用于强化戒指和项链\n\n数量: %d" % PlayerData.jewelry_enhance_stone
		"blessed_jewelry_enhance_stone":
			desc = "受祝福首饰强化石\n\n首饰强化成功率更高\n\n数量: %d" % PlayerData.blessed_jewelry_enhance_stone
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/DetailTextFrame/DetailText.text = desc
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EquipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/UnequipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EnhanceBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/DiscardBtn.visible = false

func _refresh_stats() -> void:
	var stats = PlayerData.get_final_stats()
	var ps = PlayerData.get_effective_primary_stats()
	$Panel/Margin/VBox/StatsPanel/StatsRow1.text = "STR:%d  AGI:%d  INT:%d   HP:%d  MP:%d   物攻:%d  魔攻:%d  远攻:%d" % [
		ps["STR"], ps["AGI"], ps["INT"],
		int(stats["max_hp"]), int(stats["max_mp"]),
		int(stats["melee_atk"]), int(stats["magic_atk"]), int(stats["range_atk"]),
	]
	$Panel/Margin/VBox/StatsPanel/StatsRow2.text = "防御:%d  魔防:%d  攻速:%.2f   暴击:%.0f%%  暴伤:%.0f%%  吸血:%.0f%%  闪避:%.0f%%" % [
		int(stats["def"]), int(stats.get("mdef", 0)), stats["atk_spd"],
		stats["crit_rate"] * 100, stats["crit_dmg"] * 100,
		stats["lifesteal"] * 100, stats["dodge"] * 100,
	]
	var resonance_label = $Panel/Margin/VBox/StatsPanel/StatsFooter/ResonanceLabel
	var resonance = PlayerData.get_jewelry_resonance_label()
	if resonance.is_empty():
		resonance_label.visible = false
		resonance_label.text = ""
	else:
		resonance_label.visible = true
		resonance_label.text = resonance
	$Panel/Margin/VBox/StatsPanel/StatsFooter/GoldLabel.text = "金币: %d" % PlayerData.gold

func _clear_detail() -> void:
	selected_item = {}
	_hide_enhance_panel()
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/DetailTextFrame/DetailText.text = "选择一件物品查看详情"
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EquipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/UnequipBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EnhanceBtn.visible = false
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/DiscardBtn.visible = false

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
	var is_jewelry = Equipment.is_jewelry(item)
	var quality = Equipment.get_quality_by_enhance(enhance_level)
	var quality_name = Equipment.get_quality_name(quality)
	var name_color = Equipment.get_name_color(item)
	var text = "[color=#%s]%s[/color]\n" % [name_color.to_html(false), item.get("name", "未知")]
	if is_jewelry:
		text += "首饰强化: +%d / +%d\n" % [enhance_level, Equipment.MAX_JEWELRY_ENHANCE_LEVEL]
		var line_id = item.get("jewelry_line", "")
		if not line_id.is_empty():
			text += "系别: %s\n" % _jewelry_line_name(line_id)
	else:
		text += "强化品质: %s  +%d\n" % [quality_name, enhance_level]
	if item.get("is_blessed", false) and not is_jewelry:
		text += "[color=#%s]★ 祝福装备[/color]\n" % [Equipment.BLESSED_NAME_COLOR.to_html(false)]
	var slot_label = _slot_name(item.get("slot", ""))
	if is_equipped and Equipment.is_jewelry(item):
		var ring_slot = PlayerData.get_ring_slot_for_uid(item.get("uid", ""))
		if not ring_slot.is_empty():
			slot_label = _slot_name(ring_slot)
	text += "部位: %s\n" % slot_label
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
	var active_effects = Equipment.get_active_effects(item)
	if not active_effects.is_empty():
		text += "\n特效:\n"
		for effect_key in active_effects:
			var effect_val = active_effects[effect_key]
			if effect_val is bool:
				continue
			text += "  %s: +%s\n" % [_stat_name(effect_key), _format_stat_value(effect_key, effect_val)]
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/DetailTextFrame/DetailText.text = text
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EquipBtn.visible = not is_equipped
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/UnequipBtn.visible = is_equipped
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/EnhanceBtn.visible = true
	$Panel/Margin/VBox/Content/DetailPanel/DetailVBox/ActionButtons/DiscardBtn.visible = not is_equipped

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
	var level = int(selected_item.get("enhance_level", 0))
	var item_name = $EnhanceOverlay/Center/Dialog/Margin/VBox/ItemName
	item_name.text = "%s +%d" % [selected_item.get("name", "未知"), level]
	item_name.modulate = Equipment.get_name_color(selected_item)
	$EnhanceOverlay.visible = true

func _hide_enhance_panel() -> void:
	showing_enhance = false
	$EnhanceOverlay.visible = false

func _on_enhance_dim_input(event: InputEvent) -> void:
	if not showing_enhance:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_enhance_cancel()

func _update_enhance_info() -> void:
	if selected_item.is_empty():
		return
	var level = int(selected_item.get("enhance_level", 0))
	var info = $EnhanceOverlay/Center/Dialog/Margin/VBox/EnhanceInfo
	var is_jewelry = Equipment.is_jewelry(selected_item)
	var max_level = Equipment.MAX_JEWELRY_ENHANCE_LEVEL if is_jewelry else Equipment.MAX_ENHANCE_LEVEL

	if level >= max_level:
		info.text = "[color=yellow]已达最高强化等级！[/color]"
		$EnhanceOverlay/Center/Dialog/Margin/VBox/BtnRow/ConfirmEnhanceBtn.disabled = true
		_sync_enhance_dialog_layout()
		return

	var rates: Array
	if is_jewelry:
		rates = Equipment.get_jewelry_enhance_rates()[level]
	else:
		rates = Equipment.ENHANCE_RATES[level]
	var rate = rates[1] if use_blessed_stone else rates[0]
	var stone_count: int
	if is_jewelry:
		stone_count = PlayerData.blessed_jewelry_enhance_stone if use_blessed_stone else PlayerData.jewelry_enhance_stone
	else:
		stone_count = PlayerData.blessed_enhance_stone if use_blessed_stone else PlayerData.enhance_stone
	var can_afford = stone_count >= 1

	var text = "当前强化: +%d\n" % level
	text += "成功率: [color=yellow]%.0f%%[/color]\n" % (rate * 100)
	var stone_name: String
	if is_jewelry:
		stone_name = "受祝福首饰强化石" if use_blessed_stone else "首饰强化石"
	else:
		stone_name = "受祝福强化石" if use_blessed_stone else "强化石"
	text += "消耗: %s ×1\n" % stone_name

	if is_jewelry:
		var line_id = selected_item.get("jewelry_line", "")
		var is_necklace = selected_item.get("slot", "") == "necklace"
		var next_stats: Dictionary
		var cur_stats: Dictionary
		var next_name: String
		if is_necklace:
			next_stats = DataManager.get_necklace_stats(line_id, level + 1)
			cur_stats = DataManager.get_necklace_stats(line_id, level)
			next_name = DataManager.get_necklace_name(line_id, level + 1)
		else:
			next_stats = DataManager.get_jewelry_stats(line_id, level + 1)
			cur_stats = DataManager.get_jewelry_stats(line_id, level)
			next_name = DataManager.get_jewelry_name(line_id, level + 1)
		for key in next_stats:
			var cur_val = cur_stats.get(key, 0)
			var next_val = next_stats[key]
			if next_val != cur_val:
				text += "%s: %s → %s\n" % [_stat_name(key), _format_stat_value(key, cur_val), _format_stat_value(key, next_val)]
		text += "\n名称: %s" % next_name
		var jewelry_break_text = _get_jewelry_break_risk_text(level, use_blessed_stone)
		if not jewelry_break_text.is_empty():
			text += "\n[color=orange]%s[/color]" % jewelry_break_text
	else:
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
	$EnhanceOverlay/Center/Dialog/Margin/VBox/BtnRow/ConfirmEnhanceBtn.disabled = not can_afford
	if not can_afford:
		info.text += "\n[color=red]材料不足！[/color]"
	_sync_enhance_dialog_layout()

func _get_jewelry_break_risk_text(level: int, use_blessed: bool) -> String:
	var rules = DataManager.get_enhance_rules()
	var break_rates: Array = rules.get("jewelry_break_rates", [[0.40, 0.20], [0.50, 0.25], [0.60, 0.30]])
	if level >= break_rates.size():
		level = break_rates.size() - 1
	var rates: Array = break_rates[level]
	var break_chance: float = rates[1] if use_blessed else rates[0]
	var keep_chance: float = (1.0 - break_chance) * 100.0
	if use_blessed:
		return "受祝福首饰石：失败有 %.0f%% 概率保留装备" % keep_chance
	return "警告：失败有 %.0f%% 概率损毁装备！" % (break_chance * 100.0)

func _sync_enhance_dialog_layout() -> void:
	call_deferred("_deferred_sync_enhance_dialog_layout")

func _deferred_sync_enhance_dialog_layout() -> void:
	if not showing_enhance:
		return
	var info: RichTextLabel = $EnhanceOverlay/Center/Dialog/Margin/VBox/EnhanceInfo
	info.update_minimum_size()
	$EnhanceOverlay/Center/Dialog/Margin/VBox.queue_sort()

func _on_enhance_confirm() -> void:
	if selected_item.is_empty():
		return
	if NetworkManager.logged_in and not NetworkManager.get_character_id().is_empty():
		await _enhance_confirm_server()
		return
	_enhance_confirm_local()

func _enhance_confirm_local() -> void:
	var level = int(selected_item.get("enhance_level", 0))
	var is_jewelry = Equipment.is_jewelry(selected_item)
	var max_level = Equipment.MAX_JEWELRY_ENHANCE_LEVEL if is_jewelry else Equipment.MAX_ENHANCE_LEVEL
	if level >= max_level:
		return

	if is_jewelry:
		if use_blessed_stone:
			if PlayerData.blessed_jewelry_enhance_stone < 1:
				return
			PlayerData.blessed_jewelry_enhance_stone -= 1
		else:
			if PlayerData.jewelry_enhance_stone < 1:
				return
			PlayerData.jewelry_enhance_stone -= 1
	else:
		if use_blessed_stone:
			if PlayerData.blessed_enhance_stone < 1:
				return
			PlayerData.blessed_enhance_stone -= 1
		else:
			if PlayerData.enhance_stone < 1:
				return
			PlayerData.enhance_stone -= 1

	var uid = selected_item.get("uid", "")
	var result: Dictionary
	if is_jewelry:
		result = Equipment.roll_jewelry_enhance(selected_item, use_blessed_stone)
	else:
		result = Equipment.roll_enhance(selected_item, use_blessed_stone)
	var result_color = Color.GREEN if result.get("success", false) else Color.RED
	if result.get("broken", false):
		result_color = Color(1.0, 0.3, 0.1)
		PlayerData.destroy_equipment(uid)
		selected_item = {}
		_hide_enhance_panel()
		_clear_detail()
	_show_enhance_result(result.get("message", ""), result_color)
	
	await CloudSaveService.sync_to_cloud(self, true)
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

func _enhance_confirm_server() -> void:
	var uid = selected_item.get("uid", "")
	if uid.is_empty():
		return
	$EnhanceOverlay/Center/Dialog/Margin/VBox/BtnRow/ConfirmEnhanceBtn.disabled = true
	var result = await NetworkManager.enhance_roll(uid, use_blessed_stone)
	$EnhanceOverlay/Center/Dialog/Margin/VBox/BtnRow/ConfirmEnhanceBtn.disabled = false
	if not result.get("ok", false):
		if int(result.get("code", 0)) == CloudSaveService.CONFLICT_CODE:
			var resolved := await CloudSaveService.handle_conflict(self, result, false)
			if resolved.get("ok", false):
				selected_item = PlayerData.get_equipment_by_uid(uid)
				_show_enhance_result("云端存档已刷新，请重新强化", Color(1.0, 0.85, 0.35))
				_init_stone_select()
				if not selected_item.is_empty():
					_update_enhance_info()
				_refresh_equipped()
				_refresh_inventory()
				_refresh_stats()
			return
		_show_enhance_result("强化失败: %s" % result.get("message", ""), Color.RED)
		return
	var data: Dictionary = result.get("data", {})
	var save_data: Dictionary = data.get("save", {})
	if save_data.is_empty():
		_show_enhance_result("服务器返回存档异常", Color.RED)
		return
	NetworkManager.apply_server_save(save_data, int(data.get("saveVersion", NetworkManager.get_save_version())))
	var result_color = Color.GREEN if data.get("success", false) else Color.RED
	if data.get("broken", false):
		result_color = Color(1.0, 0.3, 0.1)
		selected_item = {}
		_hide_enhance_panel()
		_clear_detail()
	else:
		selected_item = PlayerData.get_equipment_by_uid(uid)
	_show_enhance_result(str(data.get("message", "")), result_color)
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
	var info = $EnhanceOverlay/Center/Dialog/Margin/VBox/EnhanceInfo
	info.text += "\n[color=#%s]%s[/color]" % [color.to_html(false), text]
	_sync_enhance_dialog_layout()

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
	if not PlayerData.equip(uid):
		if Equipment.is_jewelry(selected_item):
			_show_alert("左右戒指槽均已装备，请先卸下其中一枚")
		else:
			_show_alert("无法装备")
		return
	await CloudSaveService.sync_to_cloud(self, true)
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
	PlayerData.unequip_by_uid(selected_item.get("uid", ""))
	await CloudSaveService.sync_to_cloud(self, true)
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
	await CloudSaveService.sync_to_cloud(self, true)
	_refresh_ui()

func _on_close() -> void:
	if get_meta("overlay_mode", false):
		queue_free()
		return
	var result = await CloudSaveService.sync_before_scene_exit(self)
	if result.get("cancelled", false):
		return
	get_tree().change_scene_to_file(ScenePaths.DUNGEON)

func _slot_name(slot: String) -> String:
	match slot:
		"weapon": return "武器"
		"helmet": return "头盔"
		"armor": return "胸甲"
		"legs": return "护腿"
		"gloves": return "护手"
		"ring", "ring_left": return "左戒"
		"ring_right": return "右戒"
		"necklace": return "项链"
	return slot

func _jewelry_line_name(line_id: String) -> String:
	match line_id:
		"power": return "强攻"
		"swift": return "迅捷"
		"prophecy": return "预言"
		"steady": return "稳固"
	return line_id

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
