extends Control

## 地图选择 — 选择要进入的地牢

const DUNGEONS := [
	{"id": "bone_crypt", "name": "荒骨墓穴", "levels": "Lv.1-15", "unlock_after": ""},
	{"id": "corrupt_swamp", "name": "腐蚀沼泽", "levels": "Lv.15-25", "unlock_after": "bone_crypt"},
	{"id": "forge_ruins", "name": "赤焰锻造厂", "levels": "Lv.20-30", "unlock_after": "corrupt_swamp"},
	{"id": "frozen_abyss", "name": "永冻深渊", "levels": "Lv.25-35", "unlock_after": "forge_ruins"},
]

func _ready() -> void:
	$VBox/BackBtn.pressed.connect(_on_back)
	$VBox/Title.add_theme_font_size_override("font_size", 32)
	$VBox/Subtitle.modulate = Color(0.7, 0.7, 0.75)
	if get_meta("show_victory", false):
		$VBox/VictoryBanner.visible = true
		$VBox/VictoryBanner.text = "🎉 通关成功！地牢领主已被击败"
	_build_map_list()

func _build_map_list() -> void:
	var list := $VBox/MapList
	for child in list.get_children():
		child.queue_free()
	for dungeon in DUNGEONS:
		var unlocked := Game.is_dungeon_unlocked(dungeon["id"])
		var cleared := Game.is_dungeon_cleared(dungeon["id"])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(420, 56)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var status := ""
		if cleared:
			status = "  [已通关]"
		elif not unlocked:
			status = "  [未解锁]"
		btn.text = "%s  %s%s" % [dungeon["name"], dungeon["levels"], status]
		btn.disabled = not unlocked
		if cleared:
			btn.modulate = Color(0.75, 0.95, 0.75)
		elif unlocked:
			btn.modulate = Color(0.9, 0.9, 0.95)
		else:
			btn.modulate = Color(0.45, 0.45, 0.5)
		btn.pressed.connect(_on_select_dungeon.bind(dungeon["id"]))
		list.add_child(btn)

func _on_select_dungeon(dungeon_id: String) -> void:
	Game.current_dungeon_id = dungeon_id
	Game.reset_dungeon()
	var stats = PlayerData.get_final_stats()
	PlayerData.current_hp = stats["max_hp"]
	PlayerData.current_mp = stats["max_mp"]
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
