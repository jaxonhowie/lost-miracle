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
	# 重置玩家数据
	PlayerData.level = 1
	PlayerData.exp = 0
	PlayerData.gold = 500
	PlayerData.enhance_stone = 5
	PlayerData.blessed_enhance_stone = 0
	PlayerData.init_default_primary_stats()
	PlayerData.equipped = {"weapon": "", "helmet": "", "armor": "", "gloves": "", "ring": "", "necklace": ""}
	PlayerData.inventory = []
	Game.reset_dungeon()
	SaveManager.save_game()
	_go_to_dungeon()

func _go_to_dungeon() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")

func _on_quit() -> void:
	get_tree().quit()
