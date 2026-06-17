extends Control

var _claiming_mail_id: int = 0


func _ready() -> void:
	_build_ui()
	await _load_mail()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.06, 0.04, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.name = "VBox"
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -360
	root.offset_top = -300
	root.offset_right = 360
	root.offset_bottom = 300
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = "邮件"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)

	var hint := Label.new()
	hint.text = "领取附件会立即写入云存档"
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


func _load_mail() -> void:
	var list: VBoxContainer = $VBox/Scroll/List
	for child in list.get_children():
		child.queue_free()

	if not NetworkManager.has_character():
		_add_message("请先选择角色")
		return

	_add_message("加载中...")
	var result := await NetworkManager.list_mail(NetworkManager.get_character_id())
	for child in list.get_children():
		child.queue_free()

	if not result.get("ok", false):
		_add_message("加载失败: %s" % result.get("message", ""))
		return

	var items: Array = result.get("data", {}).get("items", [])
	if items.is_empty():
		_add_message("暂无邮件")
		return

	for mail in items:
		list.add_child(_make_mail_row(mail))


func _make_mail_row(mail: Dictionary) -> Control:
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
	title.text = str(mail.get("title", "未命名邮件"))
	title.add_theme_font_size_override("font_size", 18)
	text_box.add_child(title)

	var body := Label.new()
	body.text = str(mail.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.modulate = Color(0.82, 0.82, 0.86)
	text_box.add_child(body)

	var attachments := Label.new()
	attachments.text = "附件: %s" % _format_rewards(mail.get("attachments", {}))
	attachments.modulate = Color(0.9, 0.78, 0.45)
	text_box.add_child(attachments)

	var created := Label.new()
	created.text = _format_time(int(mail.get("createdAt", 0)))
	created.modulate = Color(0.55, 0.6, 0.65)
	text_box.add_child(created)

	var claimed := bool(mail.get("claimed", false))
	var claim_btn := Button.new()
	claim_btn.custom_minimum_size = Vector2(120, 44)
	claim_btn.text = "已领取" if claimed else "领取"
	claim_btn.disabled = claimed or _claiming_mail_id != 0
	claim_btn.pressed.connect(_claim_mail.bind(int(mail.get("id", 0))))
	row.add_child(claim_btn)

	return panel


func _claim_mail(mail_id: int) -> void:
	if mail_id <= 0 or _claiming_mail_id != 0:
		return
	_claiming_mail_id = mail_id
	var result := await NetworkManager.claim_mail(NetworkManager.get_character_id(), mail_id)
	_claiming_mail_id = 0

	if not result.get("ok", false):
		if int(result.get("code", 0)) == CloudSaveService.CONFLICT_CODE:
			var resolved := await CloudSaveService.handle_conflict(self, result)
			if resolved.get("ok", false):
				await _show_alert("存档冲突已解决，请重新领取")
				await _load_mail()
			return
		await _show_alert("领取失败: %s" % result.get("message", ""))
		await _load_mail()
		return

	var data: Dictionary = result.get("data", {})
	NetworkManager.apply_server_save(
		data.get("save", {}),
		int(data.get("saveVersion", NetworkManager.get_save_version()))
	)
	await _show_alert("领取成功")
	await _load_mail()


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


func _format_time(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	var dt := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]


func _show_alert(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "邮件"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")


func _on_refresh() -> void:
	await _load_mail()
