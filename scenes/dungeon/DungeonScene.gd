extends Control

## 地牢探索界面

var dungeon_manager: DungeonManager

func _ready() -> void:
	dungeon_manager = DungeonManager.new()
	dungeon_manager.event_triggered.connect(_on_event_triggered)
	_update_ui()
	# 按钮连接
	$CenterPanel/ExploreBtn.pressed.connect(_on_explore)
	$BottomButtons/InventoryBtn.pressed.connect(_on_inventory)
	$BottomButtons/EnhanceBtn.pressed.connect(_on_enhance)
	$BottomButtons/SaveBtn.pressed.connect(_on_save)
	$BottomButtons/MenuBtn.pressed.connect(_on_menu)
	$EventResult/VBox/ConfirmBtn.pressed.connect(_on_event_confirm)
	# 快捷键
	set_process_unhandled_key_input(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_TAB:
				_on_inventory()
			KEY_R:
				_on_enhance()

func _update_ui() -> void:
	var stats = PlayerData.get_final_stats()
	$TopBar/PlayerInfo/NameLevel.text = "战士 Lv.%d" % PlayerData.level
	$TopBar/PlayerInfo/HPBar.max_value = stats["max_hp"]
	$TopBar/PlayerInfo/HPBar.value = PlayerData.current_hp
	$TopBar/GoldInfo.text = "金币: %d" % PlayerData.gold
	$TopBar/StoneInfo.text = "强化石: %d  受祝福: %d" % [PlayerData.enhance_stone, PlayerData.blessed_enhance_stone]
	$CenterPanel/ProgressInfo.text = "击杀: 普通 %d/15  精英 %d/3" % [
		Game.dungeon_progress["normal_kill_count"],
		Game.dungeon_progress["elite_kill_count"]
	]
	if Game.can_challenge_boss():
		$CenterPanel/ProgressInfo.text += "  ⚠ Boss入口已开启！"

func _on_explore() -> void:
	$CenterPanel/ExploreBtn.disabled = true
	dungeon_manager.explore()

func _on_event_triggered(event_type: String, event_data: Dictionary) -> void:
	match event_type:
		"normal_monster":
			_show_event("遭遇怪物！", "一只腐烂骷髅挡住了去路...", event_data)
		"elite_monster":
			_show_event("精英怪物！", "强大的精英怪物出现了！", event_data)
		"boss_entrance":
			_show_event("Boss入口！", "地牢领主的气息扑面而来...", event_data)
		"chest":
			_show_event("发现宝箱！", "你打开了宝箱，获得了 %d 金币%s" % [
				event_data.get("gold", 0),
				" 和 %d 强化石" % event_data.get("enhance_stone", 0) if event_data.get("enhance_stone", 0) > 0 else ""
			], event_data)
			PlayerData.gold += event_data.get("gold", 0)
			PlayerData.enhance_stone += event_data.get("enhance_stone", 0)
		"altar":
			_show_event("发现祭坛！", "祭坛散发出神秘的力量，你的临时属性提升了！", event_data)
		"trap":
			_show_event("陷阱！", "你触发了一个陷阱，受到 %d 点伤害！" % event_data.get("damage", 0), event_data)
			PlayerData.current_hp = maxi(1, PlayerData.current_hp - event_data.get("damage", 0))
	_update_ui()

func _show_event(title: String, desc: String, data: Dictionary) -> void:
	$EventResult/VBox/Title.text = title
	$EventResult/VBox/Description.text = desc
	$EventResult.visible = true
	$EventResult.set_meta("event_data", data)
	$EventResult.set_meta("event_title", title)

func _on_event_confirm() -> void:
	$EventResult.visible = false
	var title = $EventResult.get_meta("event_title", "")
	if title.begins_with("遭遇") or title.begins_with("精英") or title.begins_with("Boss"):
		var data = $EventResult.get_meta("event_data", {})
		_start_battle(data.get("monster_id", "rotting_skeleton"))
	else:
		$CenterPanel/ExploreBtn.disabled = false

func _start_battle(monster_id: String) -> void:
	PlayerData.reset_for_battle()
	# 传递怪物ID到战斗场景
	var battle_scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	battle_scene.set_meta("monster_id", monster_id)
	get_tree().root.add_child(battle_scene)
	get_tree().current_scene = battle_scene
	self.queue_free()

func _on_inventory() -> void:
	var scene = load("res://scenes/inventory/InventoryScene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	self.queue_free()

func _on_enhance() -> void:
	var scene = load("res://scenes/enhance/EnhanceScene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	self.queue_free()

func _on_save() -> void:
	SaveManager.save_game()
	_show_event("保存成功", "游戏已保存！", {})

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
