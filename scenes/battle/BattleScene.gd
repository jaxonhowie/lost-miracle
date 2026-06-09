extends Control

## 战斗场景 — 回合制自动战斗 + 手动技能

var battle_manager: BattleManager
var auto_battle: bool = false
var turn_timer: float = 0.0
var turn_delay: float = 1.0  # 每回合间隔
var waiting_for_turn: bool = false
var battle_over: bool = false

func _ready() -> void:
	var monster_id = get_meta("monster_id", "rotting_skeleton")
	battle_manager = BattleManager.new()
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.action_performed.connect(_on_action_performed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.log_message.connect(_on_log_message)
	# 技能按钮
	$SkillBar/Skill1.pressed.connect(_on_skill.bind("heavy_strike"))
	$SkillBar/Skill2.pressed.connect(_on_skill.bind("battle_roar"))
	$SkillBar/Skill3.pressed.connect(_on_skill.bind("blood_slash"))
	$SkillBar/AutoBtn.pressed.connect(_toggle_auto)
	# 开始战斗
	battle_manager.start_battle(monster_id)
	# 快捷键
	set_process_unhandled_key_input(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not battle_over:
		match event.keycode:
			KEY_1:
				_on_skill("heavy_strike")
			KEY_2:
				_on_skill("battle_roar")
			KEY_3:
				_on_skill("blood_slash")

func _process(delta: float) -> void:
	if battle_over:
		return
	if not battle_manager.is_battle_active:
		return
	if waiting_for_turn:
		turn_timer -= delta
		if turn_timer <= 0:
			waiting_for_turn = false
			battle_manager.execute_turn()
			_update_ui()
			# 自动进入下一回合
			if battle_manager.is_battle_active:
				_start_turn_delay()

func _start_turn_delay() -> void:
	waiting_for_turn = true
	turn_timer = turn_delay

func _on_battle_started(player: BattleUnit, monster: BattleUnit) -> void:
	$BattleArea/PlayerView/NameLabel.text = player.display_name + " Lv." + str(PlayerData.level)
	$BattleArea/MonsterView/NameLabel.text = monster.display_name
	# 设置颜色
	var monster_type = DataManager.get_monster(monster.unit_id).get("type", "normal")
	match monster_type:
		"normal":
			$BattleArea/MonsterView/Sprite.color = Color(0.5, 0.3, 0.3)
		"elite":
			$BattleArea/MonsterView/Sprite.color = Color(0.8, 0.5, 0.1)
		"boss":
			$BattleArea/MonsterView/Sprite.color = Color(0.6, 0.1, 0.1)
			$BattleArea/MonsterView/Sprite.custom_minimum_size = Vector2(200, 250)
	_update_ui()
	# 开始第一个回合延迟
	_start_turn_delay()

func _on_action_performed(attacker: BattleUnit, defender: BattleUnit, result: Dictionary) -> void:
	_update_ui()
	# 将 BattleUnit 映射到 UI 节点
	var target_view = $BattleArea/MonsterView if defender.is_player == false else $BattleArea/PlayerView
	# 震动效果
	if result.get("is_crit", false):
		_shake_sprite(target_view)
	elif not result.get("is_dodged", false):
		_flash_sprite(target_view)

func _on_battle_ended(player_won: bool, rewards: Dictionary) -> void:
	battle_over = true
	if player_won:
		# 应用奖励
		PlayerData.add_exp(rewards.get("exp", 0))
		PlayerData.gold += rewards.get("gold", 0)
		for item in rewards.get("items", []):
			if item.has("type"):
				# 货币类
				if item["type"] == "gold":
					PlayerData.gold += item.get("amount", 0)
				elif item["type"] == "enhance_stone":
					PlayerData.enhance_stone += item.get("amount", 0)
			else:
				# 装备
				PlayerData.add_to_inventory(item)
		_on_log_message("🏆 获得 %d 经验, %d 金币" % [rewards.get("exp", 0), rewards.get("gold", 0)])
		for item in rewards.get("items", []):
			if not item.has("type"):
				_on_log_message("  获得装备: %s" % item.get("name", "未知"))
		# 延迟返回地牢
		await get_tree().create_timer(2.0).timeout
		_return_to_dungeon()
	else:
		_on_log_message("💀 你阵亡了，返回地牢...")
		PlayerData.current_hp = PlayerData.get_final_stats()["max_hp"] / 2
		await get_tree().create_timer(2.0).timeout
		_return_to_dungeon()

func _return_to_dungeon() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonScene.tscn")

func _on_log_message(text: String) -> void:
	$BattleLog.append_text(text + "\n")

func _on_skill(skill_id: String) -> void:
	if battle_over or not battle_manager.is_battle_active:
		return
	battle_manager.request_skill(skill_id)

func _toggle_auto() -> void:
	auto_battle = not auto_battle
	battle_manager.auto_battle = auto_battle
	$SkillBar/AutoBtn.text = "自动中..." if auto_battle else "自动战斗"

func _update_ui() -> void:
	var p = battle_manager.player
	var m = battle_manager.monster
	if p == null or m == null:
		return
	# 玩家
	$BattleArea/PlayerView/HPBar.max_value = p.max_hp
	$BattleArea/PlayerView/HPBar.value = maxi(0, p.hp)
	$BattleArea/PlayerView/HPText.text = "HP: %d/%d" % [maxi(0, p.hp), p.max_hp]
	$BattleArea/PlayerView/MPText.text = "MP: %d/%d" % [p.mp, p.max_mp]
	# 怪物
	$BattleArea/MonsterView/HPBar.max_value = m.max_hp
	$BattleArea/MonsterView/HPBar.value = maxi(0, m.hp)
	$BattleArea/MonsterView/HPText.text = "HP: %d/%d" % [maxi(0, m.hp), m.max_hp]
	# 技能冷却
	_update_skill_buttons()

func _update_skill_buttons() -> void:
	var p = battle_manager.player
	if p == null:
		return
	var skills_data = [
		{"id": "heavy_strike", "btn": $SkillBar/Skill1, "name": "重击"},
		{"id": "battle_roar", "btn": $SkillBar/Skill2, "name": "战吼"},
		{"id": "blood_slash", "btn": $SkillBar/Skill3, "name": "血性斩击"},
	]
	for s in skills_data:
		var cd = p.skill_cooldowns.get(s["id"], 0)
		var skill_info = DataManager.get_skill(s["id"])
		var mp_cost = skill_info.get("mp_cost", 0)
		if cd > 0:
			s["btn"].text = "%s (CD:%d)" % [s["name"], cd]
			s["btn"].disabled = true
		elif p.mp < mp_cost:
			s["btn"].text = "%s (MP不足)" % s["name"]
			s["btn"].disabled = true
		else:
			s["btn"].text = "%s [%s]" % [s["name"], s["id"].substr(0, 1)]
			s["btn"].disabled = false

func _shake_sprite(unit_node: Control) -> void:
	var sprite = unit_node.get_node_or_null("Sprite")
	if sprite == null:
		return
	var tween = create_tween()
	tween.tween_property(sprite, "position:x", sprite.position.x + 10, 0.05)
	tween.tween_property(sprite, "position:x", sprite.position.x - 10, 0.05)
	tween.tween_property(sprite, "position:x", sprite.position.x, 0.05)

func _flash_sprite(unit_node: Control) -> void:
	var sprite = unit_node.get_node_or_null("Sprite")
	if sprite == null:
		return
	var original_color = sprite.color
	sprite.color = Color.WHITE
	var tween = create_tween()
	tween.tween_property(sprite, "color", original_color, 0.2)
