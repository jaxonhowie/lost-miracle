class_name BattleManager
extends RefCounted

## 战斗管理器 — 回合制自动战斗 + 手动技能

signal battle_started(player: BattleUnit, monster: BattleUnit)
signal turn_started(unit: BattleUnit)
signal action_performed(attacker: BattleUnit, defender: BattleUnit, result: Dictionary)
signal battle_ended(player_won: bool, rewards: Dictionary)
signal log_message(text: String)

var player: BattleUnit
var monster: BattleUnit
var turn_order: Array = []
var current_turn_index: int = 0
var is_battle_active: bool = false
var player_skill_pending: String = ""  # 玩家手动选择的技能
var auto_battle: bool = false

func start_battle(monster_id: String) -> void:
	player = BattleUnit.create_player()
	monster = BattleUnit.create_monster(monster_id)
	if monster == null:
		push_error("BattleManager: unknown monster " + monster_id)
		return
	is_battle_active = true
	player_skill_pending = ""
	_determine_turn_order()
	battle_started.emit(player, monster)
	log_message.emit("⚔ 战斗开始！遭遇 %s" % monster.display_name)

func _determine_turn_order() -> void:
	turn_order = [player, monster]
	if monster.spd > player.spd:
		turn_order.reverse()
	current_turn_index = 0

func execute_turn() -> void:
	if not is_battle_active:
		return
	var current_unit = turn_order[current_turn_index]
	turn_started.emit(current_unit)
	current_unit.tick_buffs()
	if current_unit.is_player:
		_execute_player_turn()
	else:
		_execute_monster_turn()
	# 检查胜负
	if not monster.is_alive():
		_end_battle(true)
		return
	if not player.is_alive():
		_end_battle(false)
		return
	# 下一个回合
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	if current_turn_index == 0:
		log_message.emit("--- 新回合 ---")

func _execute_player_turn() -> void:
	# 检查是否有手动技能
	if not player_skill_pending.is_empty():
		var skill = DataManager.get_skill(player_skill_pending)
		if not skill.is_empty() and player.skill_cooldowns.get(player_skill_pending, 0) <= 0:
			_use_skill(player, monster, skill)
			player_skill_pending = ""
			return
	# 自动战斗：自动选择技能
	if auto_battle:
		var skill_id = _pick_auto_skill()
		if not skill_id.is_empty():
			var skill = DataManager.get_skill(skill_id)
			_use_skill(player, monster, skill)
			return
	# 普通攻击
	var result = DamageCalculator.calculate_attack(player, monster)
	if result["is_dodged"]:
		log_message.emit("→ 你的攻击被 %s 闪避了！" % monster.display_name)
	else:
		monster.hp -= result["damage"]
		var msg = "→ 你对 %s 造成 %d 点伤害" % [monster.display_name, result["damage"]]
		if result["is_crit"]:
			msg += " (暴击！)"
		log_message.emit(msg)
		if player.lifesteal > 0:
			var heal = int(result["damage"] * player.lifesteal)
			player.hp = min(player.hp + heal, player.max_hp)
			if heal > 0:
				log_message.emit("  吸血恢复 %d 生命" % heal)
	action_performed.emit(player, monster, result)

func _execute_monster_turn() -> void:
	# 尝试使用技能
	for skill in monster.skills:
		var skill_id = skill.get("id", "")
		if monster.skill_cooldowns.get(skill_id, 0) > 0:
			continue
		# HP 阈值检查
		if skill.has("hp_threshold"):
			if float(monster.hp) / float(monster.max_hp) > skill.get("hp_threshold", 0):
				continue
		# 使用技能
		monster.skill_cooldowns[skill_id] = skill.get("cooldown", 1)
		if skill.get("target", "") == "self":
			# 增益技能
			var buff = skill.get("buff", {})
			if not buff.is_empty():
				monster.add_buff("def", buff.get("def_percent", 0), buff.get("duration", 1))
				log_message.emit("→ %s 使用 %s！防御提升！" % [monster.display_name, skill.get("name", "")])
		elif skill.has("debuff"):
			# 减益技能
			var debuff = skill.get("debuff", {})
			player.add_debuff("atk", debuff.get("atk_percent", 0), debuff.get("duration", 1))
			log_message.emit("→ %s 使用 %s！你的攻击力下降！" % [monster.display_name, skill.get("name", "")])
		else:
			# 伤害技能
			var result = DamageCalculator.calculate_skill_damage(monster, player, skill)
			if result["is_dodged"]:
				log_message.emit("→ %s 的 %s 被你闪避了！" % [monster.display_name, skill.get("name", "")])
			else:
				player.hp -= result["damage"]
				log_message.emit("→ %s 使用 %s，造成 %d 点伤害！" % [monster.display_name, skill.get("name", ""), result["damage"]])
		return
	# 普通攻击
	var result = DamageCalculator.calculate_attack(monster, player)
	if result["is_dodged"]:
		log_message.emit("→ %s 的攻击被你闪避了！" % monster.display_name)
	else:
		player.hp -= result["damage"]
		var msg = "→ %s 对你造成 %d 点伤害" % [monster.display_name, result["damage"]]
		if result["is_crit"]:
			msg += " (暴击！)"
		log_message.emit(msg)
	action_performed.emit(monster, player, result)

func _use_skill(user: BattleUnit, target: BattleUnit, skill: Dictionary) -> void:
	var skill_id = skill.get("id", "")
	user.skill_cooldowns[skill_id] = skill.get("cooldown", 1)
	# MP 消耗
	if user.is_player:
		user.mp -= skill.get("mp_cost", 0)
	if skill.get("target", "") == "self":
		# 增益技能
		var buff = skill.get("buff", {})
		if not buff.is_empty():
			user.add_buff("atk", buff.get("atk_percent", 0), buff.get("duration", 1))
			log_message.emit("→ 你使用 %s！攻击力提升！" % skill.get("name", ""))
	else:
		# 伤害技能
		var result = DamageCalculator.calculate_skill_damage(user, target, skill)
		if result["is_dodged"]:
			log_message.emit("→ 你的 %s 被 %s 闪避了！" % [skill.get("name", ""), target.display_name])
		else:
			target.hp -= result["damage"]
			var msg = "→ 你使用 %s，对 %s 造成 %d 点伤害" % [skill.get("name", ""), target.display_name, result["damage"]]
			if result["is_crit"]:
				msg += " (暴击！)"
			log_message.emit(msg)
			if result.get("heal", 0) > 0:
				user.hp = min(user.hp + result["heal"], user.max_hp)
				log_message.emit("  吸血恢复 %d 生命" % result["heal"])
		action_performed.emit(user, target, result)

func _pick_auto_skill() -> String:
	# 优先级：战吼(buff) > 血性斩击(吸血) > 重击(伤害)
	var hp_ratio = float(player.hp) / float(player.max_hp)
	# 战吼：没buff且CD好
	if player.skill_cooldowns.get("battle_roar", 0) <= 0 and player.mp >= 30:
		var has_atk_buff = false
		for buff in player.buffs:
			if buff.get("stat", "") == "atk":
				has_atk_buff = true
				break
		if not has_atk_buff:
			return "battle_roar"
	# 血性斩击：CD好，且(HP低或MP充足)
	if player.skill_cooldowns.get("blood_slash", 0) <= 0 and player.mp >= 25:
		if hp_ratio < 0.6 or player.mp > player.max_mp * 0.5:
			return "blood_slash"
	# 重击：CD好且MP充足
	if player.skill_cooldowns.get("heavy_strike", 0) <= 0 and player.mp >= 20:
		return "heavy_strike"
	return ""

func request_skill(skill_id: String) -> void:
	if not is_battle_active:
		return
	var skill = DataManager.get_skill(skill_id)
	if skill.is_empty():
		return
	if player.skill_cooldowns.get(skill_id, 0) > 0:
		log_message.emit("技能冷却中！")
		return
	if player.mp < skill.get("mp_cost", 0):
		log_message.emit("MP 不足！")
		return
	player_skill_pending = skill_id

func _end_battle(player_won: bool) -> void:
	is_battle_active = false
	if player_won:
		log_message.emit("🏆 你击败了 %s！" % monster.display_name)
		# 记录击杀
		var monster_type = DataManager.get_monster(monster.unit_id).get("type", "normal")
		if monster_type == "normal":
			Game.dungeon_progress["normal_kill_count"] += 1
		elif monster_type == "elite":
			Game.dungeon_progress["elite_kill_count"] += 1
		elif monster_type == "boss":
			Game.dungeon_progress["boss_defeated"] = true
	else:
		log_message.emit("💀 你被 %s 击败了..." % monster.display_name)
	# 保存战斗后 HP
	PlayerData.current_hp = maxi(1, player.hp) if player_won else 0
	PlayerData.current_mp = player.mp
	battle_ended.emit(player_won, _generate_rewards(player_won))

func _generate_rewards(player_won: bool) -> Dictionary:
	if not player_won:
		return {"exp": 0, "gold": 0, "items": []}
	var monster_data = DataManager.get_monster(monster.unit_id)
	var exp_reward = monster_data.get("level", 1) * 30
	var gold_reward = monster_data.get("level", 1) * 15 + randi() % 20
	var rewards = {"exp": exp_reward, "gold": gold_reward, "items": []}
	# 掉落装备
	var loot = LootManager.roll_drops(monster.unit_id)
	rewards["items"] = loot
	return rewards
