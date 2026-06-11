extends Control

## 地牢探索界面

var dungeon_manager: DungeonManager

func _ready() -> void:
	dungeon_manager = DungeonManager.new()
	dungeon_manager.event_triggered.connect(_on_event_triggered)
	_update_ui()
	$CenterPanel/ExploreBtn.pressed.connect(_on_explore)
	$CenterPanel/EliteBtn.pressed.connect(_on_challenge_elite)
	$CenterPanel/BossBtn.pressed.connect(_on_challenge_boss)
	$BottomButtons/InventoryBtn.pressed.connect(_on_inventory)
	$BottomButtons/SaveBtn.pressed.connect(_on_save)
	$BottomButtons/MenuBtn.pressed.connect(_on_menu)
	$EventResult/VBox/ConfirmBtn.pressed.connect(_on_event_confirm)
	if Game.auto_battle:
		$CenterPanel/ExploreBtn.disabled = true
		await get_tree().create_timer(1.0).timeout
		dungeon_manager.explore()

func _process(_delta: float) -> void:
	if not Game.is_boss_available() or not Game.is_elite_available():
		_update_spawn_buttons()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_on_inventory()
				accept_event()
			KEY_R:
				_on_inventory(true)
				accept_event()

func _update_ui() -> void:
	var stats = PlayerData.get_final_stats()
	var player_class_name = _get_class_name(Game.get_player_class())
	$TopBar/PlayerInfo/NameLevel.text = "%s Lv.%d" % [player_class_name, PlayerData.level]
	$TopBar/PlayerInfo/HPBar.max_value = stats["max_hp"]
	$TopBar/PlayerInfo/HPBar.value = PlayerData.current_hp
	$TopBar/GoldInfo.text = "金币: %d" % PlayerData.gold
	$TopBar/StoneInfo.text = "强化石: %d  受祝福: %d  药水: %d" % [
		PlayerData.enhance_stone, PlayerData.blessed_enhance_stone, PlayerData.health_potion]
	var dp = Game.dungeon_progress
	var total = int(dp["normal_kill_count"]) + int(dp["elite_kill_count"]) + int(dp.get("boss_kill_count", 0))
	$CenterPanel/ProgressInfo.text = "累计击杀: %d（普通 %d / 精英 %d / Boss %d）" % [
		total, dp["normal_kill_count"], dp["elite_kill_count"], dp.get("boss_kill_count", 0),
	]
	_update_spawn_buttons()

func _update_spawn_buttons() -> void:
	var elite_btn = $CenterPanel/EliteBtn
	var boss_btn = $CenterPanel/BossBtn
	if Game.is_elite_available():
		elite_btn.disabled = false
		elite_btn.text = "挑战精英"
	else:
		elite_btn.disabled = true
		elite_btn.text = "精英刷新 %s" % Game.format_cooldown(Game.get_elite_cooldown_remaining())
	if Game.is_boss_available():
		boss_btn.disabled = false
		boss_btn.text = "挑战Boss"
	else:
		boss_btn.disabled = true
		boss_btn.text = "Boss刷新 %s" % Game.format_cooldown(Game.get_boss_cooldown_remaining())

func _altar_stat_name(stat: String) -> String:
	match stat:
		"atk": return "攻击力"
		"def": return "防御力"
		"max_hp": return "生命值"
		_: return "属性"

func _get_class_name(cls: String) -> String:
	match cls:
		"warrior": return "战士"
		"ranger": return "游侠"
		"assassin": return "刺客"
		"elven": return "精灵"
		_: return "战士"

func _pick_elite_id() -> String:
	var monsters = DataManager.get_monsters_by_type("elite")
	if monsters.is_empty():
		return "bone_guardian"
	return monsters[randi() % monsters.size()].get("id", "bone_guardian")

func _pick_boss_id() -> String:
	var monsters = DataManager.get_monsters_by_type("boss")
	if monsters.is_empty():
		return "dungeon_lord_morgan"
	return monsters[0].get("id", "dungeon_lord_morgan")

func _on_explore() -> void:
	$CenterPanel/ExploreBtn.disabled = true
	dungeon_manager.explore()

func _on_challenge_elite() -> void:
	if not Game.is_elite_available():
		return
	_start_battle(_pick_elite_id())

func _on_challenge_boss() -> void:
	if not Game.is_boss_available():
		return
	_start_battle(_pick_boss_id())

func _on_event_triggered(event_type: String, event_data: Dictionary) -> void:
	match event_type:
		"normal_monster":
			if Game.auto_battle:
				_log_event("遭遇怪物！")
				_start_battle(event_data.get("monster_id", "rotting_skeleton"))
			else:
				_show_event("遭遇怪物！", "一只怪物挡住了去路...", event_data)
		"elite_monster":
			if Game.auto_battle:
				_log_event("挑战精英怪！")
				_start_battle(event_data.get("monster_id", _pick_elite_id()))
			else:
				_show_event("精英怪物！", "强大的精英怪物出现了！", event_data)
		"chest":
			var gold = event_data.get("gold", 0)
			var stone = event_data.get("enhance_stone", 0)
			PlayerData.gold += gold
			PlayerData.enhance_stone += stone
			var msg = "发现宝箱！获得 %d 金币" % gold
			if stone > 0:
				msg += "，%d 强化石" % stone
			if Game.auto_battle:
				_log_event(msg)
				_auto_continue()
			else:
				_show_event("发现宝箱！", msg, event_data)
		"altar":
			var buff_type = event_data.get("buff_type", "atk")
			var buff_value = event_data.get("buff_value", 0.15)
			var duration = int(event_data.get("duration", 5))
			PlayerData.add_altar_buff(buff_type, buff_value, duration)
			var stat_name = _altar_stat_name(buff_type)
			var msg = "发现祭坛！%s临时提升 %.0f%%，持续 %d 场战斗" % [stat_name, buff_value * 100, duration]
			if Game.auto_battle:
				_log_event(msg)
				_auto_continue()
			else:
				_show_event("发现祭坛！", msg, event_data)
		"trap":
			var damage = event_data.get("damage", 0)
			PlayerData.current_hp = maxi(1, PlayerData.current_hp - damage)
			if Game.auto_battle:
				_log_event("陷阱！受到 %d 点伤害" % damage)
				_auto_continue()
			else:
				_show_event("陷阱！", "你触发了一个陷阱，受到 %d 点伤害！" % damage, event_data)
	_update_ui()

func _log_event(msg: String) -> void:
	if has_node("BattleLog"):
		$BattleLog.append_text(msg + "\n")

func _auto_continue() -> void:
	SaveManager.save_game()
	await get_tree().create_timer(1.5).timeout
	dungeon_manager.explore()

func _show_event(title: String, desc: String, data: Dictionary) -> void:
	$EventResult/VBox/Title.text = title
	$EventResult/VBox/Description.text = desc
	$EventResult.visible = true
	$EventResult.set_meta("event_data", data)
	$EventResult.set_meta("event_title", title)

func _on_event_confirm() -> void:
	$EventResult.visible = false
	var title = $EventResult.get_meta("event_title", "")
	if title.begins_with("遭遇") or title.begins_with("精英"):
		var data = $EventResult.get_meta("event_data", {})
		_start_battle(data.get("monster_id", "rotting_skeleton"))
	else:
		$CenterPanel/ExploreBtn.disabled = false

func _start_battle(monster_id: String) -> void:
	SaveManager.save_game()
	PlayerData.reset_for_battle()
	var battle_scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	battle_scene.set_meta("monster_id", monster_id)
	get_tree().root.add_child(battle_scene)
	get_tree().current_scene = battle_scene
	self.queue_free()

func _on_inventory(open_enhance: bool = false) -> void:
	var scene = load("res://scenes/inventory/InventoryScene.tscn").instantiate()
	if open_enhance:
		scene.set_meta("open_enhance", true)
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	self.queue_free()

func _on_save() -> void:
	SaveManager.save_game()
	_show_event("保存成功", "游戏已保存！", {})

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
