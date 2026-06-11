extends Control

## 强化场景

var selected_uid: String = ""
var use_blessed: bool = false

func _ready() -> void:
	$Panel/VBox/Header/CloseBtn.pressed.connect(_on_close)
	$Panel/VBox/EquipSelect.item_selected.connect(_on_select_changed)
	$Panel/VBox/EnhanceBtn.pressed.connect(_on_enhance)
	$Panel/VBox/StoneSelect/StoneOption.item_selected.connect(_on_stone_changed)
	_init_stone_select()
	_refresh_list()

func _init_stone_select() -> void:
	var option = $Panel/VBox/StoneSelect/StoneOption
	option.clear()
	option.add_item("普通强化石", 0)
	option.add_item("受祝福强化石", 1)

func _on_stone_changed(index: int) -> void:
	use_blessed = (index == 1)
	_update_detail()

func _refresh_list() -> void:
	var option = $Panel/VBox/EquipSelect
	option.clear()
	option.add_item("-- 选择装备 --", 0)
	var idx = 1
	for eq in PlayerData.inventory:
		var name_text = eq.get("name", "未知") + "  +" + str(int(eq.get("enhance_level", 0)))
		option.add_item(name_text, idx)
		option.set_item_metadata(idx, eq.get("uid", ""))
		idx += 1
	_update_detail()

func _on_select_changed(index: int) -> void:
	if index == 0:
		selected_uid = ""
	else:
		selected_uid = $Panel/VBox/EquipSelect.get_item_metadata(index)
	_update_detail()

func _update_detail() -> void:
	if selected_uid.is_empty():
		$Panel/VBox/DetailLabel.text = "选择要强化的装备"
		$Panel/VBox/InfoLabel.text = ""
		$Panel/VBox/EnhanceBtn.disabled = true
		return
	var eq = PlayerData.get_equipment_by_uid(selected_uid)
	if eq.is_empty():
		return
	var level = eq.get("enhance_level", 0)
	var quality = Equipment.get_quality_by_enhance(level)
	var quality_name = Equipment.get_quality_name(quality)
	var text = "[color=#%s]%s[/color]\n" % [Equipment.QUALITY_COLORS.get(quality, Color.WHITE).to_html(false), eq.get("name", "")]
	text += "品质: %s  强化: +%d\n" % [quality_name, level]
	text += "\n属性:\n"
	for key in eq.get("base_stats", {}):
		var base_val = eq["base_stats"][key]
		var current_val = Equipment.calc_effective_stat_value(eq, key)
		if current_val == null:
			current_val = base_val
		if current_val != base_val:
			text += "  %s: +%s (基础 +%s)\n" % [_stat_name(key), str(current_val), str(base_val)]
		else:
			text += "  %s: +%s\n" % [_stat_name(key), str(current_val)]
	var active_effects = Equipment.get_active_effects(eq)
	if not active_effects.is_empty():
		text += "\n特效:\n"
		for effect_key in active_effects:
			var effect_val = active_effects[effect_key]
			if effect_val is bool:
				continue
			text += "  %s: +%s\n" % [_stat_name(effect_key), str(effect_val)]
	# 显示强化后属性
	if level < Equipment.MAX_ENHANCE_LEVEL:
		text += "\n[color=yellow]+%d 后:[/color]\n" % (level + 1)
		for key in eq.get("base_stats", {}):
			var current_val = Equipment.calc_effective_stat_value(eq, key, level)
			var next_val = Equipment.calc_effective_stat_value(eq, key, level + 1)
			if current_val == null or next_val == null:
				continue
			var gain = next_val - current_val
			if gain > 0:
				text += "  %s: %s → %s (+%s)\n" % [_stat_name(key), str(current_val), str(next_val), str(gain)]
		# 品质变化提示
		var next_quality = Equipment.get_quality_by_enhance(level + 1)
		if next_quality != quality:
			var next_quality_name = Equipment.get_quality_name(next_quality)
			text += "\n[color=#%s]品质提升: %s → %s[/color]\n" % [
				Equipment.QUALITY_COLORS.get(next_quality, Color.WHITE).to_html(false),
				quality_name, next_quality_name
			]
	$Panel/VBox/DetailLabel.text = text
	if level >= Equipment.MAX_ENHANCE_LEVEL:
		$Panel/VBox/InfoLabel.text = "已达到最高强化等级！"
		$Panel/VBox/EnhanceBtn.disabled = true
	else:
		var rates = Equipment.ENHANCE_RATES[level]
		var rate = rates[1] if use_blessed else rates[0]
		var cost = Equipment.ENHANCE_COSTS[level]
		var stone_count = PlayerData.blessed_enhance_stone if use_blessed else PlayerData.enhance_stone
		var stone_name = "受祝福强化石" if use_blessed else "普通强化石"
		var can_afford = PlayerData.gold >= cost and stone_count >= 1
		$Panel/VBox/InfoLabel.text = "成功率: %.0f%%  金币: %d  %s: 1" % [rate * 100, cost, stone_name]
		$Panel/VBox/EnhanceBtn.disabled = not can_afford
		if not can_afford:
			$Panel/VBox/ResultLabel.text = "材料不足！"
		else:
			$Panel/VBox/ResultLabel.text = ""

func _on_enhance() -> void:
	if selected_uid.is_empty():
		return
	var eq = PlayerData.get_equipment_by_uid(selected_uid)
	if eq.is_empty():
		return
	var level = eq.get("enhance_level", 0)
	if level >= Equipment.MAX_ENHANCE_LEVEL:
		return
	var cost = Equipment.ENHANCE_COSTS[level]
	if use_blessed:
		if PlayerData.blessed_enhance_stone < 1:
			return
		PlayerData.blessed_enhance_stone -= 1
	else:
		if PlayerData.enhance_stone < 1:
			return
		PlayerData.enhance_stone -= 1
	PlayerData.gold -= cost
	var result = Equipment.roll_enhance(eq, use_blessed)
	$Panel/VBox/ResultLabel.text = result.get("message", "")
	if result.get("broken", false):
		PlayerData.destroy_equipment(selected_uid)
		selected_uid = ""
		$Panel/VBox/ResultLabel.modulate = Color(1.0, 0.3, 0.1)
	elif result.get("success", false):
		$Panel/VBox/ResultLabel.modulate = Color.GREEN
	else:
		$Panel/VBox/ResultLabel.modulate = Color.RED
	SaveManager.save_game()
	_refresh_list()

func _on_close() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")

func _stat_name(stat: String) -> String:
	match stat:
		"atk": return "攻击力"
		"def": return "防御力"
		"max_hp": return "生命值"
	return stat
