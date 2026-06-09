extends Control

## 强化场景

# 强化成功率（+0→+1 到 +8→+9）：[普通强化石, 受祝福强化石]
const ENHANCE_RATES := [
	[1.00, 1.00],  # +0→+1
	[1.00, 1.00],  # +1→+2
	[1.00, 1.00],  # +2→+3
	[0.30, 1.00],  # +3→+4
	[0.28, 0.33],  # +4→+5
	[0.20, 0.25],  # +5→+6
	[0.18, 0.23],  # +6→+7
	[0.15, 0.20],  # +7→+8
	[0.13, 0.18],  # +8→+9
]
# 强化金币消耗
const ENHANCE_COSTS := [20, 40, 80, 150, 250, 400, 650, 900, 1300]
# 最高强化等级
const MAX_ENHANCE_LEVEL := 9

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
	var quality = eq.get("quality", "normal")
	var text = "[color=#%s]%s[/color]\n" % [Equipment.QUALITY_COLORS.get(quality, Color.WHITE).to_html(false), eq.get("name", "")]
	text += "当前强化: +%d\n" % level
	text += "\n基础属性:\n"
	for key in eq.get("base_stats", {}):
		text += "  %s: +%s\n" % [_stat_name(key), str(eq["base_stats"][key])]
	# 显示强化后属性
	if level < MAX_ENHANCE_LEVEL:
		text += "\n[color=yellow]+%d 后:[/color]\n" % (level + 1)
		for key in eq.get("base_stats", {}):
			var base_val = eq["base_stats"][key]
			var current_val = _calc_enhanced_value(key, base_val, level, eq.get("slot", ""))
			var next_val = _calc_enhanced_value(key, base_val, level + 1, eq.get("slot", ""))
			var gain = next_val - current_val
			if gain > 0:
				text += "  %s: %d → %d (+%d)\n" % [_stat_name(key), current_val, next_val, gain]
	$Panel/VBox/DetailLabel.text = text
	if level >= MAX_ENHANCE_LEVEL:
		$Panel/VBox/InfoLabel.text = "已达到最高强化等级！"
		$Panel/VBox/EnhanceBtn.disabled = true
	else:
		var rates = ENHANCE_RATES[level]
		var rate = rates[1] if use_blessed else rates[0]
		var cost = ENHANCE_COSTS[level]
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
	if level >= MAX_ENHANCE_LEVEL:
		return
	var cost = ENHANCE_COSTS[level]
	var rates = ENHANCE_RATES[level]
	var rate = rates[1] if use_blessed else rates[0]
	# 检查并扣除材料
	if use_blessed:
		if PlayerData.blessed_enhance_stone < 1:
			return
		PlayerData.blessed_enhance_stone -= 1
	else:
		if PlayerData.enhance_stone < 1:
			return
		PlayerData.enhance_stone -= 1
	PlayerData.gold -= cost
	if randf() < rate:
		# 成功
		eq["enhance_level"] = level + 1
		$Panel/VBox/ResultLabel.text = "强化成功！+%d" % (level + 1)
		$Panel/VBox/ResultLabel.modulate = Color.GREEN
	else:
		# 失败（不降级）
		$Panel/VBox/ResultLabel.text = "强化失败...材料已消耗"
		$Panel/VBox/ResultLabel.modulate = Color.RED
	SaveManager.save_game()
	_update_detail()

func _on_close() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")

func _calc_enhanced_value(stat: String, base_val: int, level: int, slot: String) -> int:
	if level == 0:
		return base_val
	var bonus := 0
	match slot:
		"weapon":
			if stat == "atk":
				# +1~+4: +1/级, +5: +2, +6: +3, +7: +3, +8: +3
				for i in range(1, level + 1):
					if i <= 4:
						bonus += 1
					elif i == 5:
						bonus += 2
					else:  # +6, +7, +8
						bonus += 3
		"armor", "helmet":
			if stat == "def":
				# +1~+4: +1/级, +5: +1, +6: +2, +7: +2, +8: +3
				for i in range(1, level + 1):
					if i <= 5:
						bonus += 1
					elif i <= 7:
						bonus += 2
					else:  # +8
						bonus += 3
			elif stat == "max_hp":
				# 防具生命值: +1~+4: +1/级, +5: +1, +6: +2, +7: +2, +8: +3
				for i in range(1, level + 1):
					if i <= 5:
						bonus += 1
					elif i <= 7:
						bonus += 2
					else:  # +8
						bonus += 3
	return base_val + bonus

## 获取当前强化特效等级（0=无, 1=初级, 2=二级, 3=终极）
static func get_enhance_effect_level(level: int) -> int:
	if level >= 8:
		return 3  # 终极特效
	elif level >= 7:
		return 2  # 二级特效
	elif level >= 5:
		return 1  # 初级特效
	return 0

## 获取特效描述文本
static func get_enhance_effect_name(level: int) -> String:
	var effect_lv = get_enhance_effect_level(level)
	match effect_lv:
		1: return "初级特效"
		2: return "二级特效"
		3: return "终极特效"
	return ""

func _stat_name(stat: String) -> String:
	match stat:
		"atk": return "攻击力"
		"def": return "防御力"
		"max_hp": return "生命值"
	return stat
