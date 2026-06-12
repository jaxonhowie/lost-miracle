extends Control

## 主菜单 — 最近三个存档槽

func _ready() -> void:
	$Header/Title.add_theme_font_size_override("font_size", 36)
	$Header/Subtitle.add_theme_font_size_override("font_size", 16)
	$Header/Subtitle.modulate = Color(0.7, 0.7, 0.7)
	$QuitBtn.pressed.connect(_on_quit)
	_build_save_list()

func _build_save_list() -> void:
	var list = $SaveList
	for child in list.get_children():
		child.queue_free()
	for slot in SaveManager.get_display_slots():
		if slot.get("empty", true):
			list.add_child(_make_empty_slot())
		else:
			list.add_child(_make_save_slot(slot.get("meta", {})))

func _make_save_slot(meta: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 1)
	style.border_color = Color(0.45, 0.38, 0.55, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(496, 72)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var player_class = str(meta.get("player_class", ""))
	var level = int(meta.get("level", 1))
	var login_text = SaveManager.format_last_login(int(meta.get("last_login_at", 0)))
	var map_name = SaveManager.format_dungeon_name(str(meta.get("current_dungeon_id", "")))
	var player_class_name = SaveManager.format_class_name(player_class)

	btn.text = "%s  Lv.%d\n上次登录: %s\n地图: %s" % [player_class_name, level, login_text, map_name]
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_load_save.bind(str(meta.get("id", ""))))
	panel.add_child(btn)
	return panel

func _make_empty_slot() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.11, 1)
	style.border_color = Color(0.28, 0.26, 0.34, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(496, 72)
	btn.text = "+\n创建新存档"
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_new_save)
	panel.add_child(btn)
	return panel

func _on_load_save(save_id: String) -> void:
	if save_id.is_empty():
		return
	if not SaveManager.load_game(save_id):
		_build_save_list()
		return
	_go_to_dungeon()

func _on_new_save() -> void:
	SaveManager.create_new_save()
	_go_to_map()

func _go_to_dungeon() -> void:
	var stats = PlayerData.get_final_stats()
	PlayerData.current_hp = stats["max_hp"]
	PlayerData.current_mp = stats["max_mp"]
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")

func _go_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map/MapSelectScene.tscn")

func _on_quit() -> void:
	get_tree().quit()
