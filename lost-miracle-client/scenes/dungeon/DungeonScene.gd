extends Control

## 地牢探索界面

var dungeon_manager: DungeonManager
var _xp_bar_hover := false

func _ready() -> void:
	dungeon_manager = DungeonManager.new()
	_setup_xp_bar_hover()
	_update_ui()
	_update_auto_btn()
	$CenterPanel/ExploreBtn.pressed.connect(_on_explore)
	$CenterPanel/EliteBtn.pressed.connect(_on_challenge_elite)
	$CenterPanel/BossBtn.pressed.connect(_on_challenge_boss)
	$BottomButtons/ShortcutHints/InventoryHint.pressed.connect(_on_inventory)
	$BottomButtons/ShortcutHints/EnhanceHint.pressed.connect(_on_inventory.bind(true))
	$BottomButtons/ShortcutHints/MailHint.pressed.connect(_on_mail)
	$BottomButtons/ShortcutHints/AchievementHint.pressed.connect(_on_achievements)
	$BottomButtons/AutoBtn.pressed.connect(_toggle_auto)
	$BottomButtons/MapSelectBtn.pressed.connect(_on_map_select)
	$BottomButtons/MenuBtn.pressed.connect(_on_menu)
	$EventResult/VBox/ConfirmBtn.pressed.connect(_on_event_confirm)
	CloudSaveService.try_resume_sync()
	await SpawnService.refresh(Game.current_dungeon_id)
	_update_spawn_buttons()
	_start_spawn_poll()
	if Game.auto_battle:
		$CenterPanel/ExploreBtn.disabled = true
		await get_tree().create_timer(1.0).timeout
		await _do_explore()

func _process(delta: float) -> void:
	PlayerData.tick_regen(delta)
	_update_resource_bars()

func _start_spawn_poll() -> void:
	while is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			break
		var result := await SpawnService.refresh(Game.current_dungeon_id)
		if result.get("ok", false):
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
	var player_class_name = _get_class_name(Game.get_player_class())
	$TopBar/PlayerInfo/LevelLabel.text = "%s  Lv.%d" % [player_class_name, PlayerData.level]
	_update_resource_bars()
	$TopBar/RightInfo/GoldInfo.text = "金币: %d" % PlayerData.gold
	var dungeon_name = _get_dungeon_name(Game.current_dungeon_id)
	$TopBar/RightInfo/MapInfo.text = dungeon_name
	$CenterPanel/DungeonImage/FloorLabel.text = dungeon_name
	var dp = Game.dungeon_progress
	var total = int(dp["normal_kill_count"]) + int(dp["elite_kill_count"]) + int(dp.get("boss_kill_count", 0))
	$CenterPanel/ProgressInfo.text = "累计击杀: %d（普通 %d / 精英 %d / Boss %d）" % [
		total, dp["normal_kill_count"], dp["elite_kill_count"], dp.get("boss_kill_count", 0),
	]
	_update_spawn_buttons()

func _update_resource_bars() -> void:
	var stats = PlayerData.get_final_stats()
	var max_hp = int(stats["max_hp"])
	var max_mp = int(stats["max_mp"])
	var hp = int(PlayerData.current_hp)
	var mp = int(PlayerData.current_mp)
	$TopBar/PlayerInfo/HPBarRow/HPBar.max_value = max_hp
	$TopBar/PlayerInfo/HPBarRow/HPBar.value = hp
	$TopBar/PlayerInfo/HPBarRow/HPLabel.text = "%d/%d" % [hp, max_hp]
	$TopBar/PlayerInfo/MPBarRow/MPBar.max_value = max_mp
	$TopBar/PlayerInfo/MPBarRow/MPBar.value = mp
	$TopBar/PlayerInfo/MPBarRow/MPLabel.text = "%d/%d" % [mp, max_mp]
	var max_exp = PlayerData.exp_required()
	var current_exp = PlayerData.exp
	$TopBar/PlayerInfo/XPBarRow/XPBar.max_value = max_exp
	$TopBar/PlayerInfo/XPBarRow/XPBar.value = current_exp
	_update_xp_label()

func _setup_xp_bar_hover() -> void:
	var xp_row = $TopBar/PlayerInfo/XPBarRow
	xp_row.mouse_filter = Control.MOUSE_FILTER_STOP
	xp_row.mouse_entered.connect(_on_xp_bar_hover_changed.bind(true))
	xp_row.mouse_exited.connect(_on_xp_bar_hover_changed.bind(false))
	for child in xp_row.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_xp_bar_hover_changed(hovering: bool) -> void:
	_xp_bar_hover = hovering
	_update_xp_label()

func _update_xp_label() -> void:
	var max_exp = PlayerData.exp_required()
	var current_exp = PlayerData.exp
	var label = $TopBar/PlayerInfo/XPBarRow/XPLabel
	if _xp_bar_hover:
		label.text = "%d/%d" % [current_exp, max_exp]
	elif max_exp <= 0:
		label.text = "0%"
	else:
		var pct = float(current_exp) / float(max_exp) * 100.0
		label.text = "%.1f%%" % pct

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

func _get_dungeon_name(dungeon_id: String) -> String:
	match dungeon_id:
		"bone_crypt": return "荒骨墓穴"
		"corrupt_swamp": return "腐蚀沼泽"
		"forge_ruins": return "赤焰锻造厂"
		"frozen_abyss": return "永冻深渊"
		_: return "未知地牢"

func _on_explore() -> void:
	$CenterPanel/ExploreBtn.disabled = true
	await _do_explore()

func _do_explore() -> void:
	if Game.auto_battle and SpawnService.is_elite_available():
		var chance = DataManager.get_elite_auto_chance()
		if randf() < chance:
			await _begin_spawn_battle("elite")
			return
	var event_type = dungeon_manager.roll_event_type()
	if event_type == "normal_monster":
		await _begin_spawn_battle("normal")
		return
	_handle_non_combat_event(event_type, dungeon_manager.generate_event_data(event_type))

func _begin_spawn_battle(spawn_type: String) -> void:
	var result = await SpawnService.encounter(spawn_type, Game.current_dungeon_id)
	if not result.get("ok", false):
		await _on_spawn_unavailable(spawn_type)
		return
	var data: Dictionary = result.get("data", {})
	var monster_id := str(data.get("monsterId", ""))
	var slot_id := ApiIds.from_value(data.get("slotId", 0))
	if spawn_type == "normal" and not Game.auto_battle:
		_show_event("遭遇怪物！", "一只怪物挡住了去路...", {
			"monster_id": monster_id,
			"spawn_slot_id": slot_id,
		})
		return
	if spawn_type == "elite" and not Game.auto_battle:
		_show_event("精英怪物！", "强大的精英怪物出现了！", {
			"monster_id": monster_id,
			"spawn_slot_id": slot_id,
		})
		return
	_start_battle(monster_id, slot_id)

func _on_spawn_unavailable(spawn_type: String) -> void:
	var msg := "暂无可用怪物，请稍后再试"
	match spawn_type:
		"elite":
			msg = "精英刷新 %s" % Game.format_cooldown(SpawnService.get_elite_cooldown_remaining())
		"boss":
			msg = "Boss刷新 %s" % Game.format_cooldown(SpawnService.get_boss_cooldown_remaining())
	if Game.auto_battle:
		_log_event(msg)
		await get_tree().create_timer(2.0).timeout
		$CenterPanel/ExploreBtn.disabled = false
		await _do_explore()
	else:
		_log_event(msg)
		$CenterPanel/ExploreBtn.disabled = false
	await SpawnService.refresh(Game.current_dungeon_id)
	_update_spawn_buttons()

func _on_challenge_elite() -> void:
	if not Game.is_elite_available():
		return
	$CenterPanel/ExploreBtn.disabled = true
	await _begin_spawn_battle("elite")

func _on_challenge_boss() -> void:
	if not Game.is_boss_available():
		return
	$CenterPanel/ExploreBtn.disabled = true
	await _begin_spawn_battle("boss")

func _handle_non_combat_event(event_type: String, event_data: Dictionary) -> void:
	match event_type:
		"chest":
			var gold = event_data.get("gold", 0)
			var stone = event_data.get("enhance_stone", 0)
			var jewelry_stone = event_data.get("jewelry_enhance_stone", 0)
			var blessed_jewelry = event_data.get("blessed_jewelry_enhance_stone", 0)
			PlayerData.gold += gold
			PlayerData.enhance_stone += stone
			PlayerData.jewelry_enhance_stone += jewelry_stone
			PlayerData.blessed_jewelry_enhance_stone += blessed_jewelry
			var msg = "发现宝箱！获得 %d 金币" % gold
			if stone > 0:
				msg += "，%d 强化石" % stone
			if jewelry_stone > 0:
				msg += "，%d 首饰强化石" % jewelry_stone
			if blessed_jewelry > 0:
				msg += "，%d 受祝福首饰强化石" % blessed_jewelry
			var chest_ring = event_data.get("ring", {})
			if chest_ring.has("uid"):
				PlayerData.add_to_inventory(chest_ring)
				msg += "，戒指: %s" % chest_ring.get("name", "未知")
			var chest_necklace = event_data.get("necklace", {})
			if chest_necklace.has("uid"):
				PlayerData.add_to_inventory(chest_necklace)
				msg += "，项链: %s" % chest_necklace.get("name", "未知")
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
	await get_tree().create_timer(1.5).timeout
	await _do_explore()

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
		_start_battle(
			str(data.get("monster_id", "rotting_skeleton")),
			ApiIds.from_value(data.get("spawn_slot_id", ""))
		)
	else:
		CloudSaveService.queue_progress_sync()
		$CenterPanel/ExploreBtn.disabled = false

func _start_battle(monster_id: String, spawn_slot_id: String = "") -> void:
	if not Game.auto_battle:
		await CloudSaveService.sync_to_cloud(self, false)
	PlayerData.reset_for_battle()
	var battle_scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	battle_scene.set_meta("monster_id", monster_id)
	if not spawn_slot_id.is_empty():
		battle_scene.set_meta("spawn_slot_id", spawn_slot_id)
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

func _on_mail() -> void:
	var result = await CloudSaveService.sync_before_scene_exit(self)
	if result.get("cancelled", false):
		return
	if not result.get("ok", false):
		return
	get_tree().change_scene_to_file("res://scenes/mail/MailScene.tscn")

func _on_achievements() -> void:
	var result = await CloudSaveService.sync_before_scene_exit(self)
	if result.get("cancelled", false):
		return
	if not result.get("ok", false):
		return
	get_tree().change_scene_to_file("res://scenes/achievements/AchievementScene.tscn")

func _on_map_select() -> void:
	var result = await CloudSaveService.sync_before_scene_exit(self)
	if result.get("cancelled", false):
		return
	if not result.get("ok", false):
		return
	get_tree().change_scene_to_file("res://scenes/map/MapSelectScene.tscn")

func _on_menu() -> void:
	var result = await CloudSaveService.sync_before_scene_exit(self)
	if result.get("cancelled", false):
		return
	if not result.get("ok", false):
		return
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _toggle_auto() -> void:
	if Game.auto_battle:
		Game.auto_battle = false
		if not $EventResult.visible:
			$CenterPanel/ExploreBtn.disabled = false
	else:
		Game.auto_battle = true
		if not $EventResult.visible and not $CenterPanel/ExploreBtn.disabled:
			$CenterPanel/ExploreBtn.disabled = true
			dungeon_manager.explore()
	_update_auto_btn()

func _update_auto_btn() -> void:
	var btn := $BottomButtons/AutoBtn
	if Game.auto_battle:
		btn.text = "⚡ 自动中"
		btn.modulate = Color(0.7, 0.9, 1.0)
	else:
		btn.text = "⚡ 自动"
		btn.modulate = Color.WHITE
