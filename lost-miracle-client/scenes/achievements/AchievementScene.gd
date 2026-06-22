extends Control

var _claiming_id: String = ""


func _ready() -> void:
	_build_ui()
	await _load_achievements()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.06, 0.04, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.name = "VBox"
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -380
	root.offset_top = -300
	root.offset_right = 380
	root.offset_bottom = 300
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = "成就"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)

	var hint := Label.new()
	hint.text = "达成等级目标后可领取奖励"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.7, 0.75, 0.8)
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)

	var refresh_btn := Button.new()
	refresh_btn.text = "刷新"
	refresh_btn.custom_minimum_size = Vector2(160, 44)
	refresh_btn.pressed.connect(_on_refresh)
	row.add_child(refresh_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "返回地牢"
	back_btn.custom_minimum_size = Vector2(160, 44)
	back_btn.pressed.connect(_on_back)
	row.add_child(back_btn)


func _load_achievements() -> void:
	var list: VBoxContainer = $VBox/Scroll/List
	for child in list.get_children():
		child.queue_free()

	if not NetworkManager.has_character():
		_add_message("请先选择角色")
		return

	_add_message("加载中...")
	var result := await NetworkManager.list_achievements(NetworkManager.get_character_id())
	for child in list.get_children():
		child.queue_free()

	if not result.get("ok", false):
		_add_message("加载失败: %s" % result.get("message", ""))
		return

	var items: Array = result.get("data", {}).get("items", [])
	if items.is_empty():
		_add_message("暂无成就")
		return

	for item in items:
		list.add_child(_make_achievement_row(item))


func _make_achievement_row(item: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 1)
	style.border_color = Color(0.36, 0.3, 0.45, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)

	var title := Label.new()
	title.text = str(item.get("title", "未命名成就"))
	title.add_theme_font_size_override("font_size", 18)
	text_box.add_child(title)

	var desc := Label.new()
	desc.text = str(item.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = Color(0.82, 0.82, 0.86)
	text_box.add_child(desc)

	var progress := Label.new()
	progress.text = "进度: %d/%d" % [int(item.get("progress", 0)), int(item.get("target", 0))]
	progress.modulate = Color(0.7, 0.85, 0.95)
	text_box.add_child(progress)

	var rewards := Label.new()
	rewards.text = "奖励: %s" % _format_rewards(item.get("rewards", {}))
	rewards.modulate = Color(0.9, 0.78, 0.45)
	text_box.add_child(rewards)

	var completed := bool(item.get("completed", false))
	var claimed := bool(item.get("claimed", false))
	var claim_btn := Button.new()
	claim_btn.custom_minimum_size = Vector2(120, 44)
	if claimed:
		claim_btn.text = "已领取"
	elif completed:
		claim_btn.text = "领取"
	else:
		claim_btn.text = "未完成"
	claim_btn.disabled = claimed or not completed or not _claiming_id.is_empty()
	claim_btn.pressed.connect(_claim_achievement.bind(str(item.get("id", ""))))
	row.add_child(claim_btn)

	return panel


func _claim_achievement(achievement_id: String) -> void:
	if achievement_id.is_empty() or not _claiming_id.is_empty():
		return
	_claiming_id = achievement_id
	var result := await NetworkManager.claim_achievement(NetworkManager.get_character_id(), achievement_id)
	_claiming_id = ""

	if not result.get("ok", false):
		if int(result.get("code", 0)) == CloudSaveService.CONFLICT_CODE:
			var resolved := await CloudSaveService.handle_conflict(self, result, false)
			if resolved.get("ok", false):
				await _show_alert("云端存档已刷新，请重新领取")
				await _load_achievements()
			return
		await _show_alert("领取失败: %s" % result.get("message", ""))
		await _load_achievements()
		return

	var data: Dictionary = result.get("data", {})
	NetworkManager.apply_server_save(
		data.get("save", {}),
		int(data.get("saveVersion", NetworkManager.get_save_version()))
	)
	await _show_alert("领取成功")
	await _load_achievements()


func _add_message(message: String) -> void:
	var list: VBoxContainer = $VBox/Scroll/List
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	list.add_child(label)


func _format_rewards(rewards: Variant) -> String:
	if not (rewards is Dictionary):
		return "无"
	var parts := []
	for key in rewards.keys():
		var amount := int(rewards[key])
		if amount == 0:
			continue
		parts.append("%s x%d" % [_reward_name(str(key)), amount])
	if parts.is_empty():
		return "无"
	return _join_parts(parts)


func _reward_name(key: String) -> String:
	match key:
		"gold": return "金币"
		"enhance_stone": return "强化石"
		"blessed_enhance_stone": return "祝福强化石"
		"jewelry_enhance_stone": return "首饰强化石"
		"blessed_jewelry_enhance_stone": return "祝福首饰强化石"
		"health_potion": return "生命药水"
		_: return key


func _join_parts(parts: Array) -> String:
	var text := ""
	for part in parts:
		if not text.is_empty():
			text += "，"
		text += str(part)
	return text


func _show_alert(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "成就"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()


func _on_back() -> void:
	get_tree().change_scene_to_file(ScenePaths.DUNGEON)


func _on_refresh() -> void:
	await _load_achievements()
