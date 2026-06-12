extends Node

## 玩家数据 — 基础属性、进阶属性、装备、背包、货币

var level: int = 1
var exp: int = 0
var gold: int = 500
var enhance_stone: int = 5
var blessed_enhance_stone: int = 0
var jewelry_enhance_stone: int = 0
var blessed_jewelry_enhance_stone: int = 0
var health_potion: int = 0

# 基础属性（STR/AGI/INT）— 属性系统核心
var primary_stats := {
	"STR": 10,
	"AGI": 3,
	"INT": 3,
}

# 向后兼容：由 _derive_primary_stats 计算，不再直接使用
var base_stats := {
	"max_hp": 150,
	"max_mp": 80,
	"atk": 13,
	"def": 1,
	"spd": 10,
	"crit_rate": 0.05,
	"crit_dmg": 1.5,
	"lifesteal": 0.0,
	"dodge": 0.05,
	"hit": 1.0,
}

# 当前 HP/MP（不写入存档，探索/战斗间继承）
var current_hp: int = 150
var current_mp: int = 80

const REGEN_INTERVAL := 3.0
var _regen_accumulator: float = 0.0

# 装备栏 slot -> equipment_uid
var equipped := {
	"weapon": "",
	"helmet": "",
	"armor": "",
	"legs": "",
	"gloves": "",
	"ring_left": "",
	"ring_right": "",
	"necklace": "",
}

# 背包：装备实例数组
var inventory: Array = []

# 祭坛临时增益 [{stat, value, battles_remaining}]
var altar_buffs: Array = []

# 战吼全局 Buff（真实时间倒计时，跨战斗/探索持续）
var battle_roar_remaining: float = 0.0
var battle_roar_atk_spd_percent: float = 0.0

# 经验需求
func exp_required() -> int:
	return level * level * 50

func add_exp(amount: int) -> bool:
	exp += amount
	var leveled = false
	while exp >= exp_required():
		exp -= exp_required()
		level += 1
		_on_level_up()
		leveled = true
	return leveled

func _on_level_up() -> void:
	# 根据职业自动分配属性
	var player_class = Game.get_player_class()
	# 获取职业对应的属性映射
	var class_stats = _get_class_stats(player_class)
	var main_stat = class_stats["main"]
	var sub_a = class_stats["sub_a"]
	var sub_b = class_stats["sub_b"]
	# 每级 +1 主属性
	primary_stats[main_stat] += 1
	# 每3级循环：副A → 副B → 主
	# (level-1) % 3: 0=副A, 1=副B, 2=主
	var cycle = (level - 1) % 3
	match cycle:
		0: primary_stats[sub_a] += 1
		1: primary_stats[sub_b] += 1
		2: primary_stats[main_stat] += 1
	# 同步 base_stats
	_sync_base_stats()
	# 升级回复满血满蓝
	current_hp = get_final_stats()["max_hp"]
	current_mp = get_final_stats()["max_mp"]

## 获取职业属性映射
func _get_class_stats(player_class: String) -> Dictionary:
	match player_class:
		"warrior":
			return {"main": "STR", "sub_a": "AGI", "sub_b": "INT"}
		"ranger", "assassin":
			return {"main": "AGI", "sub_a": "STR", "sub_b": "INT"}
		"elven":
			return {"main": "INT", "sub_a": "STR", "sub_b": "AGI"}
		_:
			# 默认战士
			return {"main": "STR", "sub_a": "AGI", "sub_b": "INT"}

## 同步 base_stats（向后兼容）
func _sync_base_stats() -> void:
	base_stats = _derive_base_stats_from_primary()

## 从基础属性推导 base_stats
func _derive_base_stats_from_primary() -> Dictionary:
	var s = primary_stats["STR"]
	var a = primary_stats["AGI"]
	var i = primary_stats["INT"]
	return {
		"max_hp": 100 + s * 5,
		"max_mp": 50 + i * 10,
		"atk": 10 + int(s / 3),
		"def": int(a / 3),
		"spd": a,  # 攻速基数
		"crit_rate": 0.05 + s * 0.005,
		"crit_dmg": 1.5,
		"lifesteal": 0.0,
		"dodge": 0.05 + a * 0.005,
		"hit": 1.0,
	}

## 获取最终属性（基础属性公式 + 装备 + 套装）
func get_final_stats() -> Dictionary:
	var bonus_primary := {"STR": 0, "AGI": 0, "INT": 0}
	for slot in equipped:
		var uid = equipped[slot]
		if uid.is_empty():
			continue
		var eq = get_equipment_by_uid(uid)
		if eq.is_empty() or not Equipment.is_jewelry(eq):
			continue
		var eq_base = eq.get("base_stats", {})
		for key in ["STR", "AGI", "INT"]:
			if eq_base.has(key):
				bonus_primary[key] += int(eq_base[key])

	var s = primary_stats["STR"] + bonus_primary["STR"]
	var a = primary_stats["AGI"] + bonus_primary["AGI"]
	var i = primary_stats["INT"] + bonus_primary["INT"]

	var stats := {
		# 生命/魔法
		"max_hp": 100 + s * 5,
		"max_mp": 50 + i * 10,
		# 三系攻击
		"melee_atk": 10 + int(s / 3),
		"range_atk": 10 + int(a / 3),
		"magic_atk": 10 + i,
		# 攻速
		"atk_spd": 1.0 + a * 0.01,
		# 暴击
		"crit_rate": 0.05 + s * 0.005,
		"crit_dmg": 1.5,
		# 防御
		"def": int(a / 3),
		"mdef": int(i / 3),
		# 闪避
		"dodge": 0.05 + a * 0.005,
		# 兼容性：atk = melee_atk（旧代码读取 atk）
		"atk": 10 + int(s / 3),
		# 其他（保持兼容）
		"lifesteal": 0.0,
		"hit": 1.0,
	}

	# 装备加成
	for slot in equipped:
		var uid = equipped[slot]
		if uid.is_empty():
			continue
		var eq = get_equipment_by_uid(uid)
		if eq.is_empty():
			continue
		_apply_equipment_stats(stats, eq)

	# 套装加成
	_apply_set_bonuses(stats)

	# 异系双 +3 戒指共鸣
	_apply_jewelry_resonance(stats)

	# 祭坛临时增益
	_apply_altar_buffs(stats)

	# 同步 atk 和 spd
	stats["atk"] = stats["melee_atk"]
	stats["spd"] = int(stats["atk_spd"] * 10)

	# 确保最低值
	stats["max_hp"] = maxi(1, stats["max_hp"])
	stats["max_mp"] = maxi(0, stats["max_mp"])
	stats["melee_atk"] = maxi(1, stats["melee_atk"])
	stats["range_atk"] = maxi(1, stats["range_atk"])
	stats["magic_atk"] = maxi(1, stats["magic_atk"])
	stats["atk"] = maxi(1, stats["atk"])
	
	# 属性上限 clamp
	stats["crit_rate"] = clampf(stats["crit_rate"], 0.05, 0.75)
	stats["crit_dmg"] = clampf(stats["crit_dmg"], 1.0, 3.0)
	stats["dodge"] = clampf(stats["dodge"], 0.05, 0.60)
	stats["atk_spd"] = clampf(stats["atk_spd"], 0.5, 3.0)
	stats["lifesteal"] = clampf(stats.get("lifesteal", 0.0), 0.0, 0.30)
	stats["damage_reduce"] = clampf(stats.get("damage_reduce", 0.0), 0.0, 0.30)

	return stats

func _apply_equipment_stats(stats: Dictionary, eq: Dictionary) -> void:
	if Equipment.is_jewelry(eq):
		var eq_base = eq.get("base_stats", {})
		for key in eq_base:
			if key in ["STR", "AGI", "INT"]:
				continue
			var value = eq_base[key]
			if key in ["crit_rate", "crit_dmg", "lifesteal", "dodge", "hit", "atk_spd",
						"undead_damage", "damage_reduce", "skill_damage"]:
				stats[key] = stats.get(key, 0.0) + float(value)
			elif stats.has(key):
				stats[key] += int(value)
		return

	# 装备基础属性
	var eq_base = eq.get("base_stats", {})
	var enhance_level = int(eq.get("enhance_level", 0))
	var quality = Equipment.get_quality_by_enhance(enhance_level)
	var quality_mult = Equipment.get_quality_multiplier(quality)
	var stat_mult = quality_mult
	
	# 强化品质倍率作用于该装备的基础属性
	for key in eq_base:
		if stats.has(key):
			var value = int(eq_base[key] * stat_mult)
			stats[key] += value
	# 兼容：武器ATK加成同时加到三系攻击
	var weapon_atk = eq_base.get("atk", 0)
	if weapon_atk > 0:
		for atk_key in ["melee_atk", "range_atk", "magic_atk"]:
			if not eq_base.has(atk_key):
				stats[atk_key] += int(weapon_atk * stat_mult)

	# 强化加成（扁平加值，按等级递增）
	if enhance_level > 0:
		var slot = eq.get("slot", "")
		if slot == "weapon":
			var atk_bonus = Equipment.calc_enhance_bonus("atk", enhance_level, slot)
			for atk_key in ["melee_atk", "range_atk", "magic_atk", "atk"]:
				stats[atk_key] += atk_bonus
		elif slot in ["armor", "helmet", "legs"]:
			stats["def"] += Equipment.calc_enhance_bonus("def", enhance_level, slot)
			stats["max_hp"] += Equipment.calc_enhance_bonus("max_hp", enhance_level, slot)
		elif slot in ["gloves", "necklace"]:
			var atk_bonus = Equipment.calc_enhance_bonus("atk", enhance_level, slot)
			if atk_bonus > 0:
				for atk_key in ["melee_atk", "range_atk", "magic_atk", "atk"]:
					stats[atk_key] += atk_bonus
			var def_bonus = Equipment.calc_enhance_bonus("def", enhance_level, slot)
			if def_bonus > 0:
				stats["def"] += def_bonus
			var hp_bonus = Equipment.calc_enhance_bonus("max_hp", enhance_level, slot)
			if hp_bonus > 0:
				stats["max_hp"] += hp_bonus

	# 特效加成（根据强化等级解锁）
	Equipment.apply_effects_to_stats(stats, eq)

func _apply_jewelry_resonance(stats: Dictionary) -> void:
	var left_uid = equipped.get("ring_left", "")
	var right_uid = equipped.get("ring_right", "")
	if left_uid.is_empty() or right_uid.is_empty():
		return
	var left = get_equipment_by_uid(left_uid)
	var right = get_equipment_by_uid(right_uid)
	if left.is_empty() or right.is_empty():
		return
	if int(left.get("enhance_level", 0)) < Equipment.MAX_JEWELRY_ENHANCE_LEVEL:
		return
	if int(right.get("enhance_level", 0)) < Equipment.MAX_JEWELRY_ENHANCE_LEVEL:
		return
	var line_l = left.get("jewelry_line", "")
	var line_r = right.get("jewelry_line", "")
	var resonance = DataManager.get_jewelry_resonance(line_l, line_r)
	for stat in resonance:
		var value = resonance[stat]
		if stat in ["crit_rate", "crit_dmg", "lifesteal", "dodge", "hit", "atk_spd",
					"undead_damage", "damage_reduce", "skill_damage"]:
			stats[stat] = stats.get(stat, 0.0) + float(value)
		elif stats.has(stat):
			stats[stat] += int(value)

func get_effective_primary_stats() -> Dictionary:
	var result = primary_stats.duplicate()
	for slot in equipped:
		var uid = equipped[slot]
		if uid.is_empty():
			continue
		var eq = get_equipment_by_uid(uid)
		if eq.is_empty() or not Equipment.is_jewelry(eq):
			continue
		var eq_base = eq.get("base_stats", {})
		for key in ["STR", "AGI", "INT"]:
			if eq_base.has(key):
				result[key] += int(eq_base[key])
	return result

func get_jewelry_resonance_label() -> String:
	var left_uid = equipped.get("ring_left", "")
	var right_uid = equipped.get("ring_right", "")
	if left_uid.is_empty() or right_uid.is_empty():
		return ""
	var left = get_equipment_by_uid(left_uid)
	var right = get_equipment_by_uid(right_uid)
	if int(left.get("enhance_level", 0)) < Equipment.MAX_JEWELRY_ENHANCE_LEVEL:
		return ""
	if int(right.get("enhance_level", 0)) < Equipment.MAX_JEWELRY_ENHANCE_LEVEL:
		return ""
	var line_l = left.get("jewelry_line", "")
	var line_r = right.get("jewelry_line", "")
	if line_l == line_r or line_l.is_empty() or line_r.is_empty():
		return ""
	if not DataManager.get_jewelry_resonance(line_l, line_r).is_empty():
		return "异系共鸣激活"
	return ""

func _apply_set_bonuses(stats: Dictionary) -> void:
	var set_counts := {}
	for slot in equipped:
		var uid = equipped[slot]
		if uid.is_empty():
			continue
		var eq = get_equipment_by_uid(uid)
		if eq.is_empty():
			continue
		var set_id = eq.get("set_id", "")
		if not set_id.is_empty():
			set_counts[set_id] = set_counts.get(set_id, 0) + 1
	for set_id in set_counts:
		var count = set_counts[set_id]
		var set_data = DataManager.get_set(set_id)
		if set_data.is_empty():
			continue
		for bonus in set_data.get("bonuses", []):
			if count >= bonus.get("pieces", 0):
				for effect in bonus.get("effects", []):
					var stat = effect.get("stat", "")
					var value = effect.get("value", 0)
					# 特殊属性处理
					if stat in ["undead_damage", "boss_damage", "damage_reduce",
								"lifesteal", "crit_rate", "crit_dmg", "low_hp_atk_boost",
								"undead_kill_heal", "atk_spd", "dodge", "hit", "skill_damage"]:
						stats[stat] = stats.get(stat, 0.0) + float(value)
					elif stats.has(stat):
						if effect.get("percent", false):
							stats[stat] = int(stats[stat] * (1.0 + value))
						else:
							stats[stat] += value

## 背包操作
func add_to_inventory(item: Dictionary) -> void:
	inventory.append(item)

func remove_from_inventory(uid: String) -> void:
	inventory = inventory.filter(func(e): return e.get("uid", "") != uid)

func destroy_equipment(uid: String) -> void:
	for slot in equipped:
		if equipped[slot] == uid:
			equipped[slot] = ""
	remove_from_inventory(uid)

func get_equipment_by_uid(uid: String) -> Dictionary:
	for eq in inventory:
		if eq.get("uid", "") == uid:
			return eq
	return {}

func equip(uid: String) -> bool:
	var eq = get_equipment_by_uid(uid)
	if eq.is_empty():
		return false
	var slot = eq.get("slot", "")
	var player_class = Game.get_player_class() if Game.has_method("get_player_class") else ""
	if not Equipment.can_class_equip(eq, player_class):
		return false
	if slot == "ring":
		if equipped["ring_left"].is_empty():
			equipped["ring_left"] = uid
			return true
		if equipped["ring_right"].is_empty():
			equipped["ring_right"] = uid
			return true
		return false
	if not equipped.has(slot):
		return false
	equipped[slot] = uid
	return true

func unequip(slot: String) -> bool:
	var uid = equipped.get(slot, "")
	if uid.is_empty():
		return false
	equipped[slot] = ""
	return true

func unequip_by_uid(uid: String) -> bool:
	for slot in equipped:
		if equipped[slot] == uid:
			equipped[slot] = ""
			return true
	return false

func get_ring_slot_for_uid(uid: String) -> String:
	for slot in ["ring_left", "ring_right"]:
		if equipped.get(slot, "") == uid:
			return slot
	return ""

func reset_for_battle() -> void:
	var stats = get_final_stats()
	if current_hp <= 0:
		current_hp = stats["max_hp"]
	else:
		current_hp = clampi(current_hp, 1, stats["max_hp"])
	if current_mp <= 0:
		current_mp = stats["max_mp"]
	else:
		current_mp = clampi(current_mp, 0, stats["max_mp"])

func tick_regen(delta: float, battle_unit: BattleUnit = null) -> void:
	_tick_battle_roar(delta)
	_regen_accumulator += delta
	while _regen_accumulator >= REGEN_INTERVAL:
		_regen_accumulator -= REGEN_INTERVAL
		_apply_regen_once(battle_unit)

func _apply_regen_once(battle_unit: BattleUnit = null) -> void:
	var ps = get_effective_primary_stats()
	var hp_gain = int(ps["STR"] / 3)
	var mp_gain = int(ps["INT"] / 3)
	if battle_unit:
		if hp_gain > 0:
			battle_unit.hp = mini(battle_unit.hp + hp_gain, battle_unit.max_hp)
		if mp_gain > 0:
			battle_unit.mp = mini(battle_unit.mp + mp_gain, battle_unit.max_mp)
		current_hp = battle_unit.hp
		current_mp = battle_unit.mp
	else:
		var stats = get_final_stats()
		if hp_gain > 0:
			current_hp = mini(current_hp + hp_gain, stats["max_hp"])
		if mp_gain > 0:
			current_mp = mini(current_mp + mp_gain, stats["max_mp"])

func apply_battle_roar(duration: float, atk_spd_percent: float) -> void:
	battle_roar_remaining = maxf(battle_roar_remaining, duration)
	battle_roar_atk_spd_percent = atk_spd_percent

func has_battle_roar_buff() -> bool:
	return battle_roar_remaining > 0.0

func get_battle_roar_remaining() -> float:
	return maxf(0.0, battle_roar_remaining)

func _tick_battle_roar(delta: float) -> void:
	if battle_roar_remaining <= 0.0:
		return
	battle_roar_remaining = maxf(0.0, battle_roar_remaining - delta)
	if battle_roar_remaining <= 0.0:
		battle_roar_atk_spd_percent = 0.0

func has_atk_buff_in_unit(unit: BattleUnit) -> bool:
	if unit != null and unit.is_player:
		return has_battle_roar_buff()
	if unit == null:
		return false
	for buff in unit.buffs:
		if buff.get("stat", "") == "atk" and float(buff.get("remaining_time", 0)) > 0:
			return true
	return false

func get_atk_buff_remaining(unit: BattleUnit) -> float:
	if unit != null and unit.is_player:
		return get_battle_roar_remaining()
	if unit == null:
		return 0.0
	var best := 0.0
	for buff in unit.buffs:
		if buff.get("stat", "") == "atk":
			best = maxf(best, float(buff.get("remaining_time", 0)))
	return best

func add_altar_buff(buff_type: String, buff_value: float, duration: int) -> void:
	altar_buffs.append({
		"stat": buff_type,
		"value": buff_value,
		"battles_remaining": duration,
	})

func tick_altar_buffs() -> void:
	var remaining := []
	for buff in altar_buffs:
		buff["battles_remaining"] = int(buff.get("battles_remaining", 0)) - 1
		if buff["battles_remaining"] > 0:
			remaining.append(buff)
	altar_buffs = remaining

func _apply_altar_buffs(stats: Dictionary) -> void:
	for buff in altar_buffs:
		var stat = buff.get("stat", "")
		var value = buff.get("value", 0.0)
		match stat:
			"atk":
				for key in ["melee_atk", "range_atk", "magic_atk", "atk"]:
					stats[key] = int(stats[key] * (1.0 + value))
			"def":
				stats["def"] = int(stats["def"] * (1.0 + value))
			"max_hp":
				stats["max_hp"] = int(stats["max_hp"] * (1.0 + value))

## 初始化默认基础属性（新游戏或兼容旧存档）
func init_default_primary_stats() -> void:
	primary_stats = {"STR": 10, "AGI": 3, "INT": 3}
	_sync_base_stats()

func reset_for_new_game() -> void:
	level = 1
	exp = 0
	gold = 500
	enhance_stone = 5
	blessed_enhance_stone = 0
	jewelry_enhance_stone = 0
	blessed_jewelry_enhance_stone = 0
	health_potion = 0
	init_default_primary_stats()
	equipped = {"weapon": "", "helmet": "", "armor": "", "legs": "", "gloves": "", "ring_left": "", "ring_right": "", "necklace": ""}
	inventory = []
	altar_buffs = []
	battle_roar_remaining = 0.0
	battle_roar_atk_spd_percent = 0.0
	_give_starter_gear()
	var stats = get_final_stats()
	current_hp = stats["max_hp"]
	current_mp = stats["max_mp"]

func _give_starter_gear() -> void:
	var starter_ids = ["vine_wood_sword", "vine_helmet", "vine_armor", "vine_legs", "vine_gloves"]
	for base_id in starter_ids:
		var eq = Equipment.create_from_base(base_id)
		if eq.is_empty():
			continue
		inventory.append(eq)
		var slot = eq.get("slot", "")
		if equipped.has(slot):
			equipped[slot] = eq.get("uid", "")

## 从旧存档的 base_stats 迁移到 primary_stats
## 旧存档公式: max_hp=1000+50/lvl, max_mp=200+15/lvl, atk=80+5/lvl, def=30+3/lvl
func _migrate_from_base_stats() -> void:
	var old_hp = base_stats.get("max_hp", 1000)
	var old_mp = base_stats.get("max_mp", 200)
	var old_def = base_stats.get("def", 30)
	# STR: max_hp = 100 + STR*5 => STR = (hp - 100) / 5
	var est_str = int((old_hp - 100) / 5.0)
	# INT: max_mp = 50 + INT*10 => INT = (mp - 50) / 10
	var est_int = int((old_mp - 50) / 10.0)
	# AGI: def = AGI/3 => AGI = def * 3
	var est_agi = old_def * 3
	primary_stats["STR"] = maxi(1, est_str)
	primary_stats["AGI"] = maxi(1, est_agi)
	primary_stats["INT"] = maxi(1, est_int)
