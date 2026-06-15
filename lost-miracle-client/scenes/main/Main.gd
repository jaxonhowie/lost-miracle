extends Control

## 主菜单 — 云端角色槽 + 登录状态 + 云存档同步

var _selected_character_id: String = ""
var _selected_save_id: String = ""
var _cloud_characters: Array = []
var _max_slots: int = 3

func _ready() -> void:
	$Header/Title.add_theme_font_size_override("font_size", 36)
	$Header/Subtitle.add_theme_font_size_override("font_size", 16)
	$Header/Subtitle.modulate = Color(0.7, 0.7, 0.7)
	$QuitBtn.pressed.connect(_on_quit)
	NetworkManager.loginStateChanged.connect(_on_login_state_changed)

	if not NetworkManager.logged_in:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/login/LoginScene.tscn")
		return

	await _refresh_character_list()
	await CloudSaveService.flush_sync_queue(self)
	_build_account_bar()
	_build_save_list()
	CloudSaveService.sync_status_changed.connect(_on_sync_status_changed)

func _on_login_state_changed() -> void:
	_build_account_bar()

func _on_sync_status_changed(_status: int, _message: String) -> void:
	var lbl: Label = $AccountBar.get_node_or_null("SyncStatusLabel")
	if lbl:
		lbl.text = "  |  %s" % CloudSaveService.get_status_text()

func _build_account_bar() -> void:
	var bar: HBoxContainer = $AccountBar
	for child in bar.get_children():
		child.queue_free()

	if NetworkManager.logged_in:
		var lbl := Label.new()
		lbl.text = "  %s" % NetworkManager.username
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.modulate = Color(0.75, 0.85, 1.0)
		bar.add_child(lbl)

		var lb_btn := Button.new()
		lb_btn.text = "排行榜"
		lb_btn.add_theme_font_size_override("font_size", 14)
		lb_btn.pressed.connect(_on_leaderboard)
		bar.add_child(lb_btn)

		var sync_btn := Button.new()
		sync_btn.text = "云同步"
		sync_btn.add_theme_font_size_override("font_size", 14)
		sync_btn.pressed.connect(_on_cloud_sync)
		bar.add_child(sync_btn)

		var logout_btn := Button.new()
		logout_btn.text = "登出"
		logout_btn.add_theme_font_size_override("font_size", 14)
		logout_btn.pressed.connect(_on_logout)
		bar.add_child(logout_btn)

		var sync_lbl := Label.new()
		sync_lbl.name = "SyncStatusLabel"
		sync_lbl.text = "  |  %s" % CloudSaveService.get_status_text()
		sync_lbl.add_theme_font_size_override("font_size", 13)
		sync_lbl.modulate = Color(0.7, 0.8, 0.75)
		bar.add_child(sync_lbl)
	else:
		var login_btn := Button.new()
		login_btn.text = "登录 / 注册"
		login_btn.add_theme_font_size_override("font_size", 15)
		login_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/login/LoginScene.tscn"))
		bar.add_child(login_btn)

func _refresh_character_list() -> void:
	var result = await NetworkManager.list_characters()
	if result.get("ok", false):
		_cloud_characters = result["data"].get("items", [])
		_max_slots = int(result["data"].get("maxSlots", 3))
	else:
		_cloud_characters = []
		_max_slots = 3

func _build_save_list() -> void:
	var list = $SaveList
	for child in list.get_children():
		child.queue_free()
	for slot in SaveManager.get_cloud_display_slots(_cloud_characters, _max_slots):
		if slot.get("empty", true):
			list.add_child(_make_empty_slot())
		else:
			list.add_child(_make_save_slot(slot.get("meta", {})))

func _make_save_slot(meta: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(SaveManager.SLOT_WIDTH, SaveManager.SLOT_HEIGHT)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, SaveManager.SLOT_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 1)
	style.border_color = Color(0.45, 0.38, 0.55, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var btn := Button.new()
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 72)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var player_class = str(meta.get("player_class", ""))
	var level = int(meta.get("level", 1))
	var login_text = SaveManager.format_last_login(int(meta.get("last_login_at", 0)))
	var map_name = SaveManager.format_dungeon_name(str(meta.get("current_dungeon_id", "")))
	var player_class_name = SaveManager.format_class_name(player_class)
	var char_name = str(meta.get("name", ""))
	var header = char_name if not char_name.is_empty() else player_class_name
	var char_id := ApiIds.from_value(meta.get("character_id", ""))

	btn.text = "%s  Lv.%d\n上次登录: %s\n地图: %s" % [header, level, login_text, map_name]
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_load_character.bind(char_id, meta))
	panel.add_child(btn)
	hbox.add_child(panel)

	var more_btn := Button.new()
	more_btn.text = "..."
	more_btn.custom_minimum_size = Vector2(40, SaveManager.SLOT_HEIGHT)
	more_btn.add_theme_font_size_override("font_size", 18)
	more_btn.pressed.connect(_on_more_pressed.bind(char_id, str(meta.get("id", ""))))
	hbox.add_child(more_btn)

	return hbox

func _make_empty_slot() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(SaveManager.SLOT_WIDTH, SaveManager.SLOT_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.11, 1)
	style.border_color = Color(0.28, 0.26, 0.34, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var btn := Button.new()
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 72)
	btn.text = "+\n创建新角色"
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_new_character)
	panel.add_child(btn)
	return panel

func _on_load_character(character_id: String, meta: Dictionary) -> void:
	if character_id.is_empty():
		return
	NetworkManager.set_character_id(character_id)
	var save_version := int(meta.get("save_version", NetworkManager.get_save_version()))
	NetworkManager.set_save_version(save_version)

	var result = await CloudSaveService.download_for_character(character_id)
	if not result.get("ok", false):
		if int(result.get("code", 0)) == 40300 or str(result.get("message", "")).contains("character not found"):
			var re_sync = await NetworkManager.list_characters()
			if re_sync.get("ok", false):
				var items: Array = re_sync["data"].get("items", [])
				if items.is_empty():
					var create_result = await NetworkManager.create_character()
					if create_result.get("ok", false):
						var new_ch: Dictionary = create_result["data"]
						NetworkManager.set_character_id(ApiIds.from_value(new_ch.get("id", "")))
						NetworkManager.set_save_version(int(new_ch.get("saveVersion", 1)))
						SaveManager.create_new_save()
						CloudSaveService.sync_current()
						_go_to_dungeon()
						return
				else:
					var fresh_ch: Dictionary = items[0]
					var fresh_id := ApiIds.from_value(fresh_ch.get("id", ""))
					NetworkManager.set_character_id(fresh_id)
					NetworkManager.set_save_version(int(fresh_ch.get("saveVersion", 0)))
					var dl = await CloudSaveService.download_for_character(fresh_id)
					if dl.get("ok", false):
						var data: Dictionary = dl.get("data", {})
						CloudSaveService.bind_cloud_character(fresh_ch, data.get("save", {}), int(data.get("saveVersion", 0)))
						_go_to_dungeon()
						return
		_show_alert("拉取云存档失败: %s" % result.get("message", ""))
		return

	var data: Dictionary = result.get("data", {})
	var cloud_save: Dictionary = data.get("save", {})
	save_version = int(data.get("saveVersion", save_version))
	CloudSaveService.bind_cloud_character(meta, cloud_save, save_version)
	_go_to_dungeon()

func _on_new_character() -> void:
	if _server_character_count() >= _max_slots:
		_show_alert("角色槽位已满（最多 %d 个）" % _max_slots)
		return

	var create_result = await NetworkManager.create_character()
	if not create_result.get("ok", false):
		_show_alert("创建角色失败: %s" % create_result.get("message", ""))
		return

	var ch: Dictionary = create_result.get("data", {})
	var char_id := ApiIds.from_value(ch.get("id", ""))
	var save_version := int(ch.get("saveVersion", 1))
	NetworkManager.set_character_id(char_id)
	NetworkManager.set_save_version(save_version)

	var dl = await CloudSaveService.download_for_character(char_id)
	if dl.get("ok", false):
		var data: Dictionary = dl.get("data", {})
		CloudSaveService.bind_cloud_character(ch, data.get("save", {}), int(data.get("saveVersion", save_version)))
	else:
		SaveManager.create_new_save()
		SaveManager.update_manifest_for_character(char_id, ch)
		await CloudSaveService.sync_after_local_save(self, false)

	await _refresh_character_list()
	_build_save_list()
	_go_to_map()

func _on_more_pressed(character_id: String, save_id: String) -> void:
	_selected_character_id = character_id
	_selected_save_id = save_id
	var popup: PopupMenu = $SlotMenu
	popup.position = Vector2i(get_global_mouse_position()) + Vector2i(0, 20)
	popup.popup()

func _on_slot_menu_id_pressed(id: int) -> void:
	match id:
		0:
			_show_rename_dialog()
		1:
			_show_delete_confirm()

func _show_rename_dialog() -> void:
	var manifest = SaveManager.load_manifest()
	var saves: Array = manifest.get("saves", [])
	var current_name := ""
	var selected_cid := ApiIds.from_value(_selected_character_id)
	for s in saves:
		if ApiIds.from_value(s.get("character_id", "")) == selected_cid or s.get("id", "") == _selected_save_id:
			current_name = str(s.get("name", ""))
			break

	var dialog: AcceptDialog = $RenameDialog
	var line_edit: LineEdit = dialog.get_node_or_null("LineEdit")
	if line_edit:
		line_edit.text = current_name
	dialog.popup_centered(Vector2(320, 140))

func _on_rename_confirmed() -> void:
	var line_edit: LineEdit = $RenameDialog.get_node_or_null("LineEdit")
	if not line_edit:
		return
	var new_name: String = line_edit.text.strip_edges()
	if new_name.is_empty():
		return

	var manifest = SaveManager.load_manifest()
	var saves: Array = manifest.get("saves", [])
	var selected_cid := ApiIds.from_value(_selected_character_id)
	for i in saves.size():
		if ApiIds.from_value(saves[i].get("character_id", "")) == selected_cid or saves[i].get("id", "") == _selected_save_id:
			saves[i]["name"] = new_name
			break
	manifest["saves"] = saves
	SaveManager.write_manifest(manifest)
	_build_save_list()

func _show_delete_confirm() -> void:
	var selected_cid := ApiIds.from_value(_selected_character_id)
	var display_name := "角色 #%s" % _selected_character_id
	for ch in _cloud_characters:
		if ApiIds.from_value(ch.get("id", "")) == selected_cid:
			var n = str(ch.get("name", ""))
			display_name = n if not n.is_empty() else "%s Lv.%d" % [
				SaveManager.format_class_name(str(ch.get("playerClass", ""))),
				int(ch.get("level", 1)),
			]
			break

	var dialog: ConfirmationDialog = $DeleteDialog
	dialog.dialog_text = "确定删除角色「%s」吗？\n云端存档将永久删除，无法恢复。" % display_name
	dialog.popup_centered(Vector2(360, 160))

func _on_delete_confirmed() -> void:
	if _selected_character_id.is_empty():
		return

	var deleted_id := ApiIds.from_value(_selected_character_id)
	var deleted_save_id := _selected_save_id

	var result = await NetworkManager.delete_character(deleted_id)
	if not result.get("ok", false):
		var msg := str(result.get("message", ""))
		if int(result.get("code", 0)) == 40300 or msg.contains("character not found"):
			SaveManager.remove_local_character(deleted_id, deleted_save_id)
			CloudSaveService.clear_pending_sync(deleted_id)
			if NetworkManager.get_character_id() == deleted_id:
				NetworkManager.set_character_id("")
				NetworkManager.set_save_version(0)
			await _refresh_character_list()
			_build_save_list()
			_selected_character_id = ""
			_selected_save_id = ""
		_show_alert("删除失败: %s" % msg)
		return

	SaveManager.remove_local_character(deleted_id, deleted_save_id)
	CloudSaveService.clear_pending_sync(deleted_id)

	if NetworkManager.get_character_id() == deleted_id:
		NetworkManager.set_character_id("")
		NetworkManager.set_save_version(0)

	_cloud_characters = _cloud_characters.filter(func(ch):
		return ApiIds.from_value(ch.get("id", "")) != deleted_id
	)
	_selected_character_id = ""
	_selected_save_id = ""
	_build_save_list()

func _server_character_count() -> int:
	return _cloud_characters.size()

func _on_cloud_sync() -> void:
	if NetworkManager.get_character_id().is_empty():
		_show_alert("请先选择角色")
		return
	var result = await CloudSaveService.sync_after_local_save(self, true)
	if result.get("ok", false) and not result.get("skipped", false):
		_show_alert("云同步成功")
		return
	if result.get("skipped", false):
		_show_alert("当前为仅本地存档模式")
		return
	if result.get("cancelled", false):
		return
	if int(result.get("code", 0)) != CloudSaveService.CONFLICT_CODE:
		_show_alert("同步失败: %s" % result.get("message", ""))

func _on_leaderboard() -> void:
	get_tree().change_scene_to_file("res://scenes/leaderboard/LeaderboardScene.tscn")

func _on_logout() -> void:
	if not NetworkManager.get_character_id().is_empty():
		SaveManager.save_game()
		var result = await CloudSaveService.sync_before_scene_exit(self)
		if result.get("cancelled", false):
			return
	NetworkManager.logout()
	get_tree().change_scene_to_file("res://scenes/login/LoginScene.tscn")

func _go_to_dungeon() -> void:
	var stats = PlayerData.get_final_stats()
	PlayerData.current_hp = stats["max_hp"]
	PlayerData.current_mp = stats["max_mp"]
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")

func _go_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map/MapSelectScene.tscn")

func _show_alert(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "提示"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()

func _on_quit() -> void:
	NetworkManager.exit_application()
