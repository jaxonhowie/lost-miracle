class_name BattleManager
extends RefCounted

## 战斗管理器 — 实时战斗，攻速决定攻击频率

signal battle_started(player: BattleUnit, monster: BattleUnit)
signal action_performed(attacker: BattleUnit, defender: BattleUnit, result: Dictionary)
signal battle_ended(player_won: bool, rewards: Dictionary)
signal log_message(text: String)

var player: BattleUnit
var monster: BattleUnit
var is_battle_active: bool = false
var player_skill_pending: String = ""
var auto_battle: bool = false

# 攻击计时器（各自独立）
var player_attack_timer: float = 0.0
var monster_attack_timer: float = 0.0

func start_battle(monster_id: String) -> bool:
	player = BattleUnit.create_player()
	monster = BattleUnit.create_monster(monster_id)
	if monster == null:
		push_error("BattleManager: unknown monster " + monster_id)
		return false
	is_battle_active = true
	player_skill_pending = ""
	# 初始化攻击计时器（首次攻击延迟 = 攻击间隔的一半，让战斗快速开始）
	player_attack_timer = get_attack_cooldown(player) * 0.5
	monster_attack_timer = get_attack_cooldown(monster) * 0.5
	battle_started.emit(player, monster)
	log_message.emit("⚔ 战斗开始！遭遇 %s" % monster.display_name)
	return true

## 根据攻速计算攻击间隔（秒）
## spd=10 → 1.33s, spd=15 → 0.89s, spd=6 → 2.22s
func get_attack_cooldown(unit: BattleUnit) -> float:
	var spd = maxi(1, unit.spd)
	if unit.is_player and PlayerData.has_battle_roar_buff():
		spd = maxi(1, int(spd * (1.0 + PlayerData.battle_roar_atk_spd_percent)))
	return 2.0 / (spd * 0.15)

## 每帧调用，推进战斗
func tick(delta: float) -> void:
	if not is_battle_active:
		return
	player.tick_status_effects(delta)
	monster.tick_status_effects(delta)
	# 技能冷却减少
	for skill_id in player.skill_cooldowns:
		player.skill_cooldowns[skill_id] = maxf(0, player.skill_cooldowns[skill_id] - delta)
	for skill_id in monster.skill_cooldowns:
		monster.skill_cooldowns[skill_id] = maxf(0, monster.skill_cooldowns[skill_id] - delta)
	# 玩家攻击计时
	player_attack_timer -= delta
	if player_attack_timer <= 0:
		player_attack_timer += get_attack_cooldown(player)
		_execute_player_attack()
		if not is_battle_active:
			return
	# 怪物攻击计时
	monster_attack_timer -= delta
	if monster_attack_timer <= 0:
		monster_attack_timer += get_attack_cooldown(monster)
		_execute_monster_attack()

func _execute_player_attack() -> void:
	# 优先使用手动技能
	if not player_skill_pending.is_empty():
		var skill = DataManager.get_skill(player_skill_pending)
		if not skill.is_empty() and player.skill_cooldowns.get(player_skill_pending, 0) <= 0:
			if player_skill_pending == "battle_roar" and PlayerData.has_atk_buff_in_unit(player):
				player_skill_pending = ""
			else:
				_use_skill(player, monster, skill)
				player_skill_pending = ""
				_check_battle_end()
				return
	# 自动战斗：自动选择技能
	if auto_battle:
		var skill_id = _pick_auto_skill()
		if not skill_id.is_empty():
			var skill = DataManager.get_skill(skill_id)
			_use_skill(player, monster, skill)
			_check_battle_end()
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
			player.hp = mini(player.hp + heal, player.max_hp)
			if heal > 0:
				log_message.emit("  吸血恢复 %d 生命" % heal)
	action_performed.emit(player, monster, result)
	_check_battle_end()

func _execute_monster_attack() -> void:
	# 尝试使用技能
	for skill in monster.skills:
		var skill_id = skill.get("id", "")
		if monster.skill_cooldowns.get(skill_id, 0) > 0:
			continue
		if skill.has("hp_threshold"):
			if float(monster.hp) / float(monster.max_hp) > skill.get("hp_threshold", 0):
				continue
		monster.skill_cooldowns[skill_id] = skill.get("cooldown", 1)
		if skill.get("target", "") == "self":
			var buff = skill.get("buff", {})
			if not buff.is_empty():
				monster.add_buff("def", buff.get("def_percent", 0), buff.get("duration", 1))
				log_message.emit("→ %s 使用 %s！防御提升！" % [monster.display_name, skill.get("name", "")])
		elif skill.has("debuff"):
			var debuff = skill.get("debuff", {})
			player.add_debuff("atk", debuff.get("atk_percent", 0), debuff.get("duration", 1))
			log_message.emit("→ %s 使用 %s！你的攻击力下降！" % [monster.display_name, skill.get("name", "")])
		else:
			var result = DamageCalculator.calculate_skill_damage(monster, player, skill)
			if result["is_dodged"]:
				log_message.emit("→ %s 的 %s 被你闪避了！" % [monster.display_name, skill.get("name", "")])
			else:
				player.hp -= result["damage"]
				log_message.emit("→ %s 使用 %s，造成 %d 点伤害！" % [monster.display_name, skill.get("name", ""), result["damage"]])
		action_performed.emit(monster, player, {})
		_check_battle_end()
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
	_check_battle_end()

func _check_battle_end() -> void:
	if not monster.is_alive():
		_on_monster_killed()
		_end_battle(true)
	elif not player.is_alive():
		_end_battle(false)

func _on_monster_killed() -> void:
	if player.undead_kill_heal > 0:
		var heal = int(player.max_hp * player.undead_kill_heal)
		player.hp = mini(player.hp + heal, player.max_hp)
		if heal > 0:
			log_message.emit("  套装效果：击杀回复 %d 生命" % heal)

func _use_skill(user: BattleUnit, target: BattleUnit, skill: Dictionary) -> void:
	var skill_id = skill.get("id", "")
	user.skill_cooldowns[skill_id] = skill.get("cooldown", 1)
	if user.is_player:
		user.mp -= skill.get("mp_cost", 0)
	if skill.get("target", "") == "self":
		var buff = skill.get("buff", {})
		if not buff.is_empty():
			if skill_id == "battle_roar":
				PlayerData.apply_battle_roar(
					float(buff.get("duration", 300)),
					float(buff.get("atk_spd_percent", 0.2))
				)
				log_message.emit("→ 你使用 %s！攻击速度提升！" % skill.get("name", ""))
			else:
				user.add_buff("atk", buff.get("atk_percent", 0), buff.get("duration", 1))
				log_message.emit("→ 你使用 %s！攻击力提升！" % skill.get("name", ""))
	else:
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
				user.hp = mini(user.hp + result["heal"], user.max_hp)
				log_message.emit("  吸血恢复 %d 生命" % result["heal"])
		action_performed.emit(user, target, result)

func _pick_auto_skill() -> String:
	var hp_ratio = float(player.hp) / float(player.max_hp)
	if player.skill_cooldowns.get("battle_roar", 0) <= 0 and player.mp >= 20:
		if not PlayerData.has_atk_buff_in_unit(player):
			return "battle_roar"
	if player.skill_cooldowns.get("blood_slash", 0) <= 0 and player.mp >= 25:
		if hp_ratio < 0.6 or player.mp > player.max_mp * 0.5:
			return "blood_slash"
	if player.skill_cooldowns.get("heavy_strike", 0) <= 0 and player.mp >= 10:
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
	if skill_id == "battle_roar" and PlayerData.has_atk_buff_in_unit(player):
		log_message.emit("战吼效果仍在生效！")
		return
	if player.mp < skill.get("mp_cost", 0):
		log_message.emit("MP 不足！")
		return
	player_skill_pending = skill_id

func _end_battle(player_won: bool) -> void:
	is_battle_active = false
	if player_won:
		log_message.emit("🏆 你击败了 %s！" % monster.display_name)
	else:
		log_message.emit("💀 你被 %s 击败了..." % monster.display_name)
	PlayerData.current_hp = maxi(1, player.hp) if player_won else 0
	PlayerData.current_mp = player.mp
	if player_won:
		PlayerData.tick_altar_buffs()
	var rewards := {"monster_id": monster.unit_id}
	battle_ended.emit(player_won, rewards)

func _generate_rewards(player_won: bool) -> Dictionary:
	# 奖励由服务端 settle API 权威结算
	if not player_won:
		return {"exp": 0, "gold": 0, "items": []}
	return {"exp": 0, "gold": 0, "items": [], "monster_id": monster.unit_id}
