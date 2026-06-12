class_name BattleUnit
extends RefCounted

## 战斗单位 — 玩家或怪物的战斗数据

var unit_id: String = ""
var display_name: String = ""
var is_player: bool = false
var monster_type: String = ""

var hp: int = 0
var max_hp: int = 0
var mp: int = 0
var max_mp: int = 0
var atk: int = 0
var melee_atk: int = 0
var range_atk: int = 0
var magic_atk: int = 0
var atk_spd: float = 1.0
var def: int = 0
var mdef: int = 0
var spd: int = 0
var crit_rate: float = 0.0
var crit_dmg: float = 1.5
var lifesteal: float = 0.0
var dodge: float = 0.0
var hit: float = 1.0

# 战斗修饰属性
var undead_damage: float = 0.0
var boss_damage: float = 0.0
var damage_reduce: float = 0.0
var skill_damage: float = 0.0
var low_hp_atk_boost: float = 0.0
var undead_kill_heal: float = 0.0

var skills: Array = []
var buffs: Array = []  # [{stat, value, remaining_time}]
var debuffs: Array = []
var skill_cooldowns: Dictionary = {}

static func create_player() -> BattleUnit:
	var unit = BattleUnit.new()
	unit.is_player = true
	unit.unit_id = "player"
	unit.display_name = _class_display_name(Game.get_player_class())
	var stats = PlayerData.get_final_stats()
	unit.max_hp = stats.get("max_hp", 150)
	unit.hp = mini(PlayerData.current_hp, unit.max_hp)
	if unit.hp <= 0:
		unit.hp = unit.max_hp
	unit.max_mp = stats.get("max_mp", 80)
	unit.mp = mini(PlayerData.current_mp, unit.max_mp)
	unit.melee_atk = stats.get("melee_atk", 10)
	unit.range_atk = stats.get("range_atk", 10)
	unit.magic_atk = stats.get("magic_atk", 10)
	unit.atk = stats.get("atk", unit.melee_atk)
	unit.atk_spd = stats.get("atk_spd", 1.0)
	unit.def = stats.get("def", 0)
	unit.mdef = stats.get("mdef", 0)
	unit.spd = stats.get("spd", 10)
	unit.crit_rate = stats.get("crit_rate", 0.05)
	unit.crit_dmg = stats.get("crit_dmg", 1.5)
	unit.lifesteal = stats.get("lifesteal", 0.0)
	unit.dodge = stats.get("dodge", 0.0)
	unit.hit = stats.get("hit", 1.0)
	unit.undead_damage = stats.get("undead_damage", 0.0)
	unit.boss_damage = stats.get("boss_damage", 0.0)
	unit.damage_reduce = stats.get("damage_reduce", 0.0)
	unit.skill_damage = stats.get("skill_damage", 0.0)
	unit.low_hp_atk_boost = stats.get("low_hp_atk_boost", 0.0)
	unit.undead_kill_heal = stats.get("undead_kill_heal", 0.0)
	unit.skills = []
	for skill_id in ["heavy_strike", "battle_roar", "blood_slash"]:
		var skill_data = DataManager.get_skill(skill_id)
		if not skill_data.is_empty():
			unit.skills.append(skill_data.duplicate())
			unit.skill_cooldowns[skill_id] = 0
	var physique = DataManager.get_skill("warrior_physique")
	if not physique.is_empty():
		var effect = physique.get("effect", {})
		unit.max_hp = int(unit.max_hp * (1.0 + effect.get("max_hp_percent", 0)))
		unit.hp = mini(unit.hp, unit.max_hp)
	var mastery = DataManager.get_skill("weapon_mastery")
	if not mastery.is_empty():
		var effect = mastery.get("effect", {})
		unit.atk = int(unit.atk * (1.0 + effect.get("atk_percent", 0)))
	return unit

static func _class_display_name(cls: String) -> String:
	match cls:
		"warrior": return "战士"
		"ranger": return "游侠"
		"assassin": return "刺客"
		"elven": return "精灵"
		_: return "战士"

static func create_monster(monster_id: String) -> BattleUnit:
	var data = DataManager.get_monster(monster_id)
	if data.is_empty():
		return null
	var unit = BattleUnit.new()
	unit.unit_id = monster_id
	unit.display_name = data.get("name", monster_id)
	unit.monster_type = data.get("type", "normal")
	unit.max_hp = data.get("hp", 100)
	unit.hp = unit.max_hp
	unit.atk = data.get("atk", 10)
	unit.def = data.get("def", 5)
	unit.spd = data.get("spd", 10)
	unit.crit_rate = data.get("crit_rate", 0.05)
	unit.crit_dmg = data.get("crit_dmg", 1.5)
	unit.skills = []
	for skill_id in data.get("skills", []):
		var skill_data = DataManager.get_skill(skill_id)
		if not skill_data.is_empty():
			unit.skills.append(skill_data.duplicate())
			unit.skill_cooldowns[skill_id] = 0
	return unit

func is_alive() -> bool:
	return hp > 0

func get_effective_atk() -> int:
	var result = atk
	if low_hp_atk_boost > 0 and max_hp > 0:
		if float(hp) / float(max_hp) <= 0.30:
			result = int(result * (1.0 + low_hp_atk_boost))
	for buff in buffs:
		if buff.get("stat", "") == "atk":
			result += int(result * buff.get("value", 0))
	for debuff in debuffs:
		if debuff.get("stat", "") == "atk":
			result += int(result * debuff.get("value", 0))
	return maxi(1, result)

func get_effective_def() -> int:
	var result = def
	for buff in buffs:
		if buff.get("stat", "") == "def":
			result += int(result * buff.get("value", 0))
	for debuff in debuffs:
		if debuff.get("stat", "") == "def":
			result += int(result * debuff.get("value", 0))
	return maxi(0, result)

func tick_status_effects(delta: float) -> void:
	buffs = _tick_status_list(buffs, delta)
	debuffs = _tick_status_list(debuffs, delta)

func _tick_status_list(list: Array, delta: float) -> Array:
	var remaining := []
	for entry in list:
		entry["remaining_time"] = entry.get("remaining_time", 0.0) - delta
		if entry["remaining_time"] > 0:
			remaining.append(entry)
	return remaining

func add_buff(stat: String, value: float, duration: float) -> void:
	buffs.append({"stat": stat, "value": value, "remaining_time": duration})

func add_debuff(stat: String, value: float, duration: float) -> void:
	debuffs.append({"stat": stat, "value": value, "remaining_time": duration})
