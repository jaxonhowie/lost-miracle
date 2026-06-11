extends Control

## 主菜单

func _ready() -> void:
	# 设置标题字体大小
	$VBox/Title.add_theme_font_size_override("font_size", 36)
	$VBox/Subtitle.add_theme_font_size_override("font_size", 16)
	$VBox/Subtitle.modulate = Color(0.7, 0.7, 0.7)
	# 检查存档
	$VBox/ContinueBtn.visible = SaveManager.has_save()
	# 连接按钮
	$VBox/ContinueBtn.pressed.connect(_on_continue)
	$VBox/NewGameBtn.pressed.connect(_on_new_game)
	$VBox/QuitBtn.pressed.connect(_on_quit)

func _on_continue() -> void:
	SaveManager.load_game()
	_go_to_dungeon()

func _on_new_game() -> void:
	PlayerData.reset_for_new_game()
	Game.player_class = "warrior"
	Game.auto_battle = false
	Game.current_dungeon_id = "bone_crypt"
	Game.cleared_dungeons = []
	Game.reset_dungeon()
	SaveManager.save_game()
	_go_to_dungeon()

func _go_to_dungeon() -> void:
	get_tree().change_scene_to_file("res://scenes/map/MapSelectScene.tscn")

func _on_quit() -> void:
	get_tree().quit()
