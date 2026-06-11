class_name DamageCalculator
extends RefCounted

## 伤害计算器

static func calculate_attack(attacker: BattleUnit, defender: BattleUnit) -> Dictionary:
	var raw_atk = attacker.get_effective_atk()
	var raw_def = defender.get_effective_def()
	var damage = maxi(1, raw_atk - int(raw_def * 0.5))
	var is_crit = randf() < attacker.crit_rate
	if is_crit:
		damage = int(damage * attacker.crit_dmg)
	var is_dodged = randf() < defender.dodge
	if is_dodged:
		return {"damage": 0, "is_crit": false, "is_dodged": true}
	damage = _apply_damage_modifiers(damage, attacker, defender, false)
	return {"damage": damage, "is_crit": is_crit, "is_dodged": false}

static func calculate_skill_damage(attacker: BattleUnit, defender: BattleUnit, skill: Dictionary) -> Dictionary:
	var multiplier = skill.get("damage_multiplier", 1.0)
	var raw_atk = attacker.get_effective_atk()
	var raw_def = defender.get_effective_def()
	var base_damage = maxi(1, raw_atk - int(raw_def * 0.5))
	var damage = int(base_damage * multiplier)
	var is_crit = randf() < attacker.crit_rate
	if is_crit:
		damage = int(damage * attacker.crit_dmg)
	var is_dodged = randf() < defender.dodge
	if is_dodged:
		return {"damage": 0, "is_crit": false, "is_dodged": true, "skill_name": skill.get("name", "")}
	damage = _apply_damage_modifiers(damage, attacker, defender, true)
	var heal = 0
	if skill.has("lifesteal_percent"):
		heal = int(damage * skill.get("lifesteal_percent", 0))
	return {"damage": damage, "is_crit": is_crit, "is_dodged": false, "heal": heal, "skill_name": skill.get("name", "")}

static func _apply_damage_modifiers(damage: int, attacker: BattleUnit, defender: BattleUnit, is_skill: bool) -> int:
	var result = damage
	if is_skill and attacker.skill_damage > 0:
		result = int(result * (1.0 + attacker.skill_damage))
	# 对亡灵增伤（地牢怪物均为亡灵）
	if not defender.is_player and attacker.undead_damage > 0:
		result = int(result * (1.0 + attacker.undead_damage))
	# Boss 增伤
	if not defender.is_player and defender.monster_type == "boss" and attacker.boss_damage > 0:
		result = int(result * (1.0 + attacker.boss_damage))
	# 受伤降低
	if defender.damage_reduce > 0:
		result = int(result * (1.0 - defender.damage_reduce))
	return maxi(1, result)
