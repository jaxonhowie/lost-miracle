extends Control

## 战斗场景 — 实时战斗，攻速决定攻击频率

const COLOR_HP := Color(0.82, 0.22, 0.28)
const COLOR_HP_BG := Color(0.15, 0.08, 0.1)
const COLOR_MP := Color(0.28, 0.45, 0.95)
const COLOR_MP_BG := Color(0.08, 0.1, 0.18)
const COLOR_PANEL := Color(0.1, 0.08, 0.14, 0.92)
const COLOR_PANEL_BORDER := Color(0.35, 0.28, 0.45, 0.8)

var battle_manager: BattleManager
var battle_over: bool = false
var potion_cooldown: float = 0.0
var finish_then_return: bool = false
var _inventory_open: bool = false

@onready var _player_card := $BattleArea/PlayerCard/CardPanel/CardVBox
@onready var _monster_card := $BattleArea/MonsterCard/CardPanel/CardVBox
@onready var _player_avatar := $BattleArea/PlayerCard/CardPanel/CardVBox/Avatar
@onready var _monster_avatar := $BattleArea/MonsterCard/CardPanel/CardVBox/Avatar

func _ready() -> void:
	_apply_visual_theme()
	_start_ambient_animations()
	var monster_id = get_meta("monster_id", "rotting_skeleton")
	battle_manager = BattleManager.new()
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.action_performed.connect(_on_action_performed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.log_message.connect(_on_log_message)
	$SkillPanel/SkillBar/Skill1.pressed.connect(_on_skill.bind("heavy_strike"))
	$SkillPanel/SkillBar/Skill2.pressed.connect(_on_skill.bind("battle_roar"))
	$SkillPanel/SkillBar/Skill3.pressed.connect(_on_skill.bind("blood_slash"))
	$SkillPanel/SkillBar/PotionBtn.pressed.connect(_use_potion)
	$SkillPanel/SkillBar/AutoBtn.pressed.connect(_toggle_auto)
	$SkillPanel/SkillBar/InvBtn.pressed.connect(_open_inventory)
	_style_button($SkillPanel/SkillBar/InvBtn, Color(0.25, 0.22, 0.35), Color(0.4, 0.35, 0.55))
	_update_potion_btn()
	_update_auto_btn_style()
	battle_manager.auto_battle = Game.auto_battle
	if not battle_manager.start_battle(monster_id):
		var dialog := AcceptDialog.new()
		dialog.title = "战斗错误"
		dialog.dialog_text = "怪物数据加载失败: %s\n请返回重试。" % monster_id
		add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(func(): get_tree().change_scene_to_file(ScenePaths.MAP))
		return
	for child in $SkillPanel/SkillBar.get_children():
		if child is Control:
			child.focus_mode = Control.FOCUS_NONE
	$LogPanel/BattleLog.clear()
	_on_log_message("[color=#aabbcc]战斗开始...[/color]")

func _apply_visual_theme() -> void:
	var panel_style := _make_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 10)
	$TopBar.add_theme_stylebox_override("panel", panel_style)
	$BattleArea/PlayerCard/CardPanel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.12, 0.22, 0.95), Color(0.3, 0.5, 0.85, 0.7), 12))
	$BattleArea/MonsterCard/CardPanel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.18, 0.08, 0.08, 0.95), Color(0.7, 0.25, 0.2, 0.7), 12))
	$SkillPanel.add_theme_stylebox_override("panel", panel_style)
	$LogPanel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.05, 0.09, 0.95), Color(0.25, 0.22, 0.32, 0.6), 8))
	_style_bar($BattleArea/PlayerCard/CardPanel/CardVBox/HPRow/HPBar, COLOR_HP, COLOR_HP_BG)
	_style_bar($BattleArea/PlayerCard/CardPanel/CardVBox/MPRow/MPBar, COLOR_MP, COLOR_MP_BG)
	_style_bar($BattleArea/MonsterCard/CardPanel/CardVBox/HPRow/HPBar, Color(0.9, 0.35, 0.2), COLOR_HP_BG)
	_style_button($SkillPanel/SkillBar/Skill1, Color(0.55, 0.2, 0.15), Color(0.75, 0.3, 0.2))
	_style_button($SkillPanel/SkillBar/Skill2, Color(0.2, 0.35, 0.55), Color(0.3, 0.5, 0.75))
	_style_button($SkillPanel/SkillBar/Skill3, Color(0.45, 0.12, 0.2), Color(0.65, 0.2, 0.3))
	_style_button($SkillPanel/SkillBar/PotionBtn, Color(0.12, 0.4, 0.22), Color(0.2, 0.55, 0.32))
	_style_button($SkillPanel/SkillBar/AutoBtn, Color(0.25, 0.22, 0.35), Color(0.4, 0.35, 0.55))
	$TopBar/TopHBox/BattleTitle.add_theme_font_size_override("font_size", 20)
	$TopBar/TopHBox/BattleTitle.modulate = Color(0.9, 0.85, 0.95)
	$TopBar/TopHBox/BattleTitle.text = "⚔  %s · 战斗" % SaveManager.format_dungeon_name(Game.current_dungeon_id)
	$LogPanel/BattleLog.add_theme_font_size_override("normal_font_size", 13)

func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func _style_bar(bar: ProgressBar, fill: Color, bg: Color) -> void:
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(6)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg
	bg_style.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_stylebox_override("background", bg_style)

func _style_button(btn: Button, normal: Color, hover: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = normal
	n.set_corner_radius_all(8)
	n.content_margin_left = 10
	n.content_margin_right = 10
	n.content_margin_top = 6
	n.content_margin_bottom = 6
	var h := n.duplicate()
	h.bg_color = hover
	var d := n.duplicate()
	d.bg_color = normal.darkened(0.25)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", d)
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_color_override("font_color", Color(0.95, 0.93, 0.98))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.55))

func _start_ambient_animations() -> void:
	var vs := $BattleArea/VS/VSLabel
	var tween := create_tween().set_loops()
	tween.tween_property(vs, "modulate:a", 0.55, 1.2)
	tween.tween_property(vs, "modulate:a", 1.0, 1.2)
	_pulse_glow($BattleArea/PlayerCard/CardPanel/CardVBox/Avatar/Glow)
	_pulse_glow($BattleArea/MonsterCard/CardPanel/CardVBox/Avatar/Glow)

func _pulse_glow(rect: ColorRect) -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(rect, "modulate:a", 0.35, 1.8)
	tween.tween_property(rect, "modulate:a", 0.75, 1.8)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _inventory_open or battle_over:
		return
	match event.keycode:
		KEY_1:
			_on_skill("heavy_strike")
			get_viewport().set_input_as_handled()
		KEY_2:
			_on_skill("battle_roar")
			get_viewport().set_input_as_handled()
		KEY_3:
			_on_skill("blood_slash")
			get_viewport().set_input_as_handled()
		KEY_4:
			_use_potion()
			get_viewport().set_input_as_handled()
		KEY_TAB:
			_open_inventory()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if potion_cooldown > 0:
		potion_cooldown -= delta
		if potion_cooldown <= 0:
			potion_cooldown = 0
		_update_potion_btn()
	if battle_over:
		return
	if Game.auto_battle:
		_auto_use_potion()
	if battle_manager.is_battle_active:
		PlayerData.tick_regen(delta, battle_manager.player)
	battle_manager.tick(delta)
	_update_ui()

func _on_battle_started(player: BattleUnit, monster: BattleUnit) -> void:
	_player_card.get_node("NameLabel").text = player.display_name + "  Lv." + str(PlayerData.level)
	_monster_card.get_node("NameLabel").text = monster.display_name
	var monster_data = DataManager.get_monster(monster.unit_id)
	var monster_type = monster_data.get("type", "normal")
	var badge := $TopBar/TopHBox/MonsterBadge
	match monster_type:
		"normal":
			_set_monster_visual(Color(0.5, 0.22, 0.22), Color(0.55, 0.18, 0.18), "普通", Color(0.7, 0.7, 0.75))
		"elite":
			_set_monster_visual(Color(0.75, 0.45, 0.1), Color(0.85, 0.55, 0.15), "精英", Color(1.0, 0.75, 0.3))
			_monster_card.get_node("StatusText").text = "精英怪物"
		"boss":
			_set_monster_visual(Color(0.55, 0.08, 0.12), Color(0.7, 0.1, 0.15), "Boss", Color(1.0, 0.4, 0.35))
			_monster_card.get_node("StatusText").text = "地牢领主"
			badge.add_theme_font_size_override("font_size", 18)
	_update_ui()

func _set_monster_visual(glow: Color, body: Color, badge_text: String, badge_color: Color) -> void:
	_monster_avatar.get_node("Glow").color = glow
	_monster_avatar.get_node("Sprite").color = body
	var badge := $TopBar/TopHBox/MonsterBadge
	badge.text = badge_text
	badge.modulate = badge_color

func _on_action_performed(attacker: BattleUnit, defender: BattleUnit, result: Dictionary) -> void:
	_update_ui()
	var target_avatar: Control = _monster_avatar if not defender.is_player else _player_avatar
	if result.get("is_dodged", false):
		_show_float_text(target_avatar, "闪避", Color(0.7, 0.85, 1.0))
	elif result.get("is_crit", false):
		_shake_avatar(target_avatar)
		_show_float_text(target_avatar, "-%d 暴击!" % result.get("damage", 0), Color(1.0, 0.85, 0.2))
	elif result.get("damage", 0) > 0:
		_flash_avatar(target_avatar)
		var dmg_color := Color(1.0, 0.45, 0.35) if defender.is_player else Color(0.95, 0.95, 0.95)
		_show_float_text(target_avatar, "-%d" % result.get("damage", 0), dmg_color)

func _on_battle_ended(player_won: bool, rewards: Dictionary) -> void:
	battle_over = true
	var spawn_slot_id := str(get_meta("spawn_slot_id", ""))
	var monster_id := str(rewards.get("monster_id", battle_manager.monster.unit_id))
	if player_won:
		if spawn_slot_id.is_empty():
			_on_log_message("[color=#ff6666]战斗结算失败：缺少刷怪槽信息[/color]")
			return
		var settle_result = await SpawnService.settle_victory(
			Game.current_dungeon_id,
			spawn_slot_id,
			monster_id
		)
		if not settle_result.get("ok", false):
			if int(settle_result.get("code", 0)) == CloudSaveService.CONFLICT_CODE:
				await CloudSaveService.handle_conflict(self, settle_result)
				return
			else:
				_on_log_message("[color=#ff6666]战斗结算失败：%s[/color]" % str(settle_result.get("message", "未知错误")))
				return
		else:
			var data: Dictionary = settle_result.get("data", {})
			NetworkManager.apply_server_save(
				data.get("save", {}),
				int(data.get("saveVersion", NetworkManager.get_save_version()))
			)
			_log_settle_rewards(data)
		var monster_type = DataManager.get_monster(monster_id).get("type", "normal")
		if monster_type == "boss":
			_on_log_message("[color=#ffaa44]击败了地牢领主！[/color]")
		if finish_then_return:
			await get_tree().create_timer(2.0).timeout
			_return_to_dungeon()
		elif Game.auto_battle:
			_on_log_message("[color=#8899aa]--- 3秒后继续探索 ---[/color]")
			await get_tree().create_timer(3.0).timeout
			_return_to_dungeon()
		else:
			await get_tree().create_timer(2.0).timeout
			_return_to_dungeon()
	else:
		_on_log_message("[color=#ff6666]💀 你阵亡了，返回地牢...[/color]")
		if not spawn_slot_id.is_empty():
			await SpawnService.report_release(Game.current_dungeon_id, spawn_slot_id)
		PlayerData.current_hp = PlayerData.get_final_stats()["max_hp"] / 2
		await get_tree().create_timer(2.0).timeout
		_return_to_dungeon()

func _log_settle_rewards(data: Dictionary) -> void:
	var exp_gain := int(data.get("exp", 0))
	var gold_gain := int(data.get("gold", 0))
	_on_log_message("[color=#ffd666]🏆 获得 %d 经验, %d 金币[/color]" % [exp_gain, gold_gain])
	var items: Array = data.get("items", [])
	for item in items:
		if item is Dictionary:
			if item.has("uid"):
				_on_log_message("[color=#88ccff]  获得装备: %s[/color]" % item.get("name", "未知"))
			elif item.get("type", "") == "enhance_stone":
				_on_log_message("[color=#bbaaff]  获得强化石 x%d[/color]" % int(item.get("amount", 0)))
			elif item.get("type", "") == "jewelry_enhance_stone":
				_on_log_message("[color=#ffcc88]  获得首饰强化石 x%d[/color]" % int(item.get("amount", 0)))
			elif item.get("type", "") == "blessed_jewelry_enhance_stone":
				_on_log_message("[color=#ffddaa]  获得受祝福首饰强化石 x%d[/color]" % int(item.get("amount", 0)))
			elif item.get("type", "") == "health_potion":
				_on_log_message("[color=#66dd88]  获得生命药水 x%d[/color]" % int(item.get("amount", 0)))

func _return_to_dungeon() -> void:
	get_tree().change_scene_to_file(ScenePaths.DUNGEON)

func _auto_use_potion() -> void:
	if potion_cooldown > 0 or PlayerData.health_potion <= 0:
		return
	var p = battle_manager.player
	if p and float(p.hp) / float(p.max_hp) < 0.5:
		_use_potion()

func _use_potion() -> void:
	if battle_over or not battle_manager.is_battle_active:
		return
	if potion_cooldown > 0 or PlayerData.health_potion <= 0:
		return
	var p = battle_manager.player
	if p.hp >= p.max_hp:
		return
	PlayerData.health_potion -= 1
	potion_cooldown = 2.0
	var heal = 20
	p.hp = mini(p.hp + heal, p.max_hp)
	PlayerData.current_hp = p.hp
	_on_log_message("[color=#66dd88]🧪 使用生命药水，恢复 %d 生命 (剩余: %d)[/color]" % [heal, PlayerData.health_potion])
	_show_float_text(_player_avatar, "+%d" % heal, Color(0.4, 1.0, 0.55))
	_update_ui()
	_update_potion_btn()

func _update_potion_btn() -> void:
	var btn := $SkillPanel/SkillBar/PotionBtn
	if potion_cooldown > 0:
		btn.text = "🧪 %.1fs" % potion_cooldown
		btn.disabled = true
	elif PlayerData.health_potion <= 0:
		btn.text = "🧪 ×0"
		btn.disabled = true
	else:
		btn.text = "🧪 ×%d [4]" % PlayerData.health_potion
		btn.disabled = false

func _on_log_message(text: String) -> void:
	if text.begins_with("[color"):
		$LogPanel/BattleLog.append_text(text + "\n")
	else:
		$LogPanel/BattleLog.append_text("[color=#ccddee]" + text + "[/color]\n")

func _on_skill(skill_id: String) -> void:
	if battle_over or not battle_manager.is_battle_active:
		return
	battle_manager.request_skill(skill_id)

func _toggle_auto() -> void:
	if Game.auto_battle:
		Game.auto_battle = false
		battle_manager.auto_battle = false
		finish_then_return = true
		_on_log_message("[color=#8899aa]自动战斗关闭，打完当前怪物后返回地牢[/color]")
	else:
		Game.auto_battle = true
		battle_manager.auto_battle = true
		finish_then_return = false
		_on_log_message("[color=#88bbff]自动战斗已开启[/color]")
	_update_auto_btn_style()

func _update_auto_btn_style() -> void:
	var btn := $SkillPanel/SkillBar/AutoBtn
	if Game.auto_battle:
		btn.text = "⚡ 自动中"
		btn.modulate = Color(0.7, 0.9, 1.0)
	else:
		btn.text = "⚡ 自动"
		btn.modulate = Color.WHITE

func _open_inventory() -> void:
	if _inventory_open or battle_over:
		return
	_inventory_open = true
	var inv_scene = load(ScenePaths.INVENTORY).instantiate()
	inv_scene.set_meta("overlay_mode", true)
	inv_scene.set_meta("open_enhance", false)
	inv_scene.tree_exited.connect(_on_inventory_closed)
	add_child(inv_scene)
	move_child(inv_scene, $FloatLayer.get_index())

func _on_inventory_closed() -> void:
	_inventory_open = false

func _update_ui() -> void:
	var p = battle_manager.player
	var m = battle_manager.monster
	if p == null or m == null:
		return
	var php := _player_card.get_node("HPRow")
	php.get_node("HPBar").max_value = p.max_hp
	php.get_node("HPBar").value = maxi(0, p.hp)
	php.get_node("HPText").text = "%d / %d" % [maxi(0, p.hp), p.max_hp]
	var pmp := _player_card.get_node("MPRow")
	pmp.get_node("MPBar").max_value = p.max_mp
	pmp.get_node("MPBar").value = maxi(0, p.mp)
	pmp.get_node("MPText").text = "%d / %d" % [maxi(0, p.mp), p.max_mp]
	var mhp := _monster_card.get_node("HPRow")
	mhp.get_node("HPBar").max_value = m.max_hp
	mhp.get_node("HPBar").value = maxi(0, m.hp)
	mhp.get_node("HPText").text = "%d / %d" % [maxi(0, m.hp), m.max_hp]
	_update_skill_buttons()
	_update_potion_btn()
	_update_buff_display()

func _update_buff_display() -> void:
	var overlay = _player_avatar.get_node("BuffOverlay")
	if battle_over or battle_manager.player == null:
		overlay.visible = false
		return
	var remaining = PlayerData.get_atk_buff_remaining(battle_manager.player)
	if remaining > 0.0:
		overlay.visible = true
		overlay.get_node("BuffTimer").text = _format_buff_time(remaining)
	else:
		overlay.visible = false

func _format_buff_time(seconds: float) -> String:
	var total = maxi(0, int(ceil(seconds)))
	var mins = total / 60
	var secs = total % 60
	return "%d:%02d" % [mins, secs]

func _update_skill_buttons() -> void:
	var p = battle_manager.player
	if p == null:
		return
	var skills_data = [
		{"id": "heavy_strike", "btn": $SkillPanel/SkillBar/Skill1, "name": "⚔ 重击", "key": "1"},
		{"id": "battle_roar", "btn": $SkillPanel/SkillBar/Skill2, "name": "📯 战吼", "key": "2"},
		{"id": "blood_slash", "btn": $SkillPanel/SkillBar/Skill3, "name": "🩸 血腥斩击", "key": "3"},
	]
	for s in skills_data:
		var cd = p.skill_cooldowns.get(s["id"], 0)
		var skill_info = DataManager.get_skill(s["id"])
		var mp_cost = skill_info.get("mp_cost", 0)
		if cd > 0:
			s["btn"].text = "%s  %.1fs" % [s["name"], cd]
			s["btn"].disabled = true
		elif p.mp < mp_cost:
			s["btn"].text = "%s  MP不足" % s["name"]
			s["btn"].disabled = true
		else:
			s["btn"].text = "%s  [%s]" % [s["name"], s["key"]]
			s["btn"].disabled = false

func _shake_avatar(avatar: Control) -> void:
	var sprite := avatar.get_node("Sprite") as Control
	var base_x: float = sprite.position.x
	var tween := create_tween()
	tween.tween_property(sprite, "position:x", base_x + 14, 0.04)
	tween.tween_property(sprite, "position:x", base_x - 14, 0.04)
	tween.tween_property(sprite, "position:x", base_x + 8, 0.04)
	tween.tween_property(sprite, "position:x", base_x, 0.04)

func _flash_avatar(avatar: Control) -> void:
	var sprite := avatar.get_node("Sprite") as ColorRect
	var original := sprite.color
	sprite.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(sprite, "color", original, 0.18)

func _show_float_text(avatar: Control, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = color
	label.position = avatar.global_position + Vector2(avatar.size.x * 0.5 - 30, -10)
	$FloatLayer.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 48, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
