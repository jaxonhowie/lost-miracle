class_name DamageCalculator
extends RefCounted

## 伤害计算器

## 计算普通攻击伤害
static func calculate_attack(attacker: BattleUnit, defender: BattleUnit) -> Dictionary:
	var raw_atk = attacker.get_effective_atk()
	var raw_def = defender.get_effective_def()
	var damage = maxi(1, raw_atk - int(raw_def * 0.5))
	var is_crit = randf() < attacker.crit_rate
	if is_crit:
		damage = int(damage * attacker.crit_dmg)
	# 闪避判定
	var is_dodged = randf() < defender.dodge
	if is_dodged:
		return {"damage": 0, "is_crit": false, "is_dodged": true}
	return {"damage": damage, "is_crit": is_crit, "is_dodged": false}

## 计算技能伤害
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
	# 吸血计算
	var heal = 0
	if skill.has("lifesteal_percent"):
		heal = int(damage * skill.get("lifesteal_percent", 0))
	return {"damage": damage, "is_crit": is_crit, "is_dodged": false, "heal": heal, "skill_name": skill.get("name", "")}
