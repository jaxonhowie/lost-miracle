extends Node

## 玩家数据 — 基础属性、进阶属性、装备、背包、货币

var level: int = 1
var exp: int = 0
var gold: int = 500
var enhance_stone: int = 5
var blessed_enhance_stone: int = 0

# 基础属性（STR/AGI/INT）— 属性系统核心
var primary_stats := {
	"STR": 10,
	"AGI": 10,
	"INT": 10,
}

# 未分配属性点（升级获得）
var unallocated_points: int = 0

# 向后兼容：由 _derive_primary_stats 计算，不再直接使用
var base_stats := {
	"max_hp": 1000,
	"max_mp": 200,
	"atk": 80,
	"def": 30,
	"spd": 10,
	"crit_rate": 0.05,
	"crit_dmg": 1.5,
	"lifesteal": 0.0,
	"dodge": 0.0,
	"hit": 1.0,
}

# 当前战斗 HP/MP（不持久化，每次战斗开始重置）
var current_hp: int = 1000
var current_mp: int = 200

# 装备栏 slot -> equipment_uid
var equipped := {
	"weapon": "",
	"helmet": "",
	"armor": "",
	"gloves": "",
	"ring": "",
	"necklace": "",
}

# 背包：装备实例数组
var inventory: Array = []

# 经验需求
func exp_required() -> int:
	return level * 50 + 20

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
	# 升级获得2点可分配属性点
	unallocated_points += 2
	# 每级自动+1全基础属性
	primary_stats["STR"] += 1
	primary_stats["AGI"] += 1
	primary_stats["INT"] += 1
	# 同步 base_stats
	_sync_base_stats()

## 分配属性点
func allocate_point(stat: String) -> bool:
	if unallocated_points <= 0:
		return false
	if not primary_stats.has(stat):
		return false
	primary_stats[stat] += 1
	unallocated_points -= 1
	_sync_base_stats()
	return true

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
	# 从基础属性计算进阶属性
	var s = primary_stats["STR"]
	var a = primary_stats["AGI"]
	var i = primary_stats["INT"]

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

	return stats

func _apply_equipment_stats(stats: Dictionary, eq: Dictionary) -> void:
	# 装备基础属性
	var eq_base = eq.get("base_stats", {})
	for key in eq_base:
		if stats.has(key):
			stats[key] += eq_base[key]
	# 兼容：武器ATK加成同时加到三系攻击
	var weapon_atk = eq_base.get("atk", 0)
	if weapon_atk > 0:
		for atk_key in ["melee_atk", "range_atk", "magic_atk"]:
			if not eq_base.has(atk_key):
				stats[atk_key] += weapon_atk

	# 词条
	for affix in eq.get("affixes", []):
		var stat = affix.get("stat", "")
		var value = affix.get("value", 0)
		if stats.has(stat):
			stats[stat] += value

	# 强化加成（扁平加值，按等级递增）
	var enhance_level = eq.get("enhance_level", 0)
	if enhance_level > 0:
		var slot = eq.get("slot", "")
		if slot == "weapon":
			var atk_bonus = _calc_enhance_bonus("atk", enhance_level, slot)
			for atk_key in ["melee_atk", "range_atk", "magic_atk", "atk"]:
				stats[atk_key] += atk_bonus
		elif slot in ["armor", "helmet"]:
			stats["def"] += _calc_enhance_bonus("def", enhance_level, slot)
			stats["max_hp"] += _calc_enhance_bonus("max_hp", enhance_level, slot)

	# 品质倍率
	var quality_mult = _get_quality_multiplier(eq.get("quality", "normal"))
	if quality_mult > 1.0:
		for key in ["melee_atk", "range_atk", "magic_atk", "atk", "def", "max_hp"]:
			stats[key] = int(stats[key] * quality_mult)

	# 特效加成（根据强化等级解锁）
	Equipment.apply_effects_to_stats(stats, eq)

func _get_quality_multiplier(quality: String) -> float:
	match quality:
		"fine": return 1.15
		"rare": return 1.35
		"epic": return 1.60
		"legendary": return 1.85
		_: return 1.0

## 计算强化扁平加值
func _calc_enhance_bonus(stat: String, level: int, slot: String) -> int:
	var bonus := 0
	match slot:
		"weapon":
			if stat == "atk":
				for i in range(1, level + 1):
					if i <= 4:
						bonus += 1
					elif i == 5:
						bonus += 2
					else:
						bonus += 3
		"armor", "helmet":
			if stat == "def" or stat == "max_hp":
				for i in range(1, level + 1):
					if i <= 5:
						bonus += 1
					elif i <= 7:
						bonus += 2
					else:
						bonus += 3
	return bonus

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
					if stats.has(stat):
						if effect.get("percent", false):
							stats[stat] = int(stats[stat] * (1.0 + value))
						else:
							stats[stat] += value

## 背包操作
func add_to_inventory(item: Dictionary) -> void:
	inventory.append(item)

func remove_from_inventory(uid: String) -> void:
	inventory = inventory.filter(func(e): return e.get("uid", "") != uid)

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
	if not equipped.has(slot):
		return false
	# 职业限制检查
	var player_class = Game.get_player_class() if Game.has_method("get_player_class") else ""
	if not Equipment.can_class_equip(eq, player_class):
		return false
	# 卸下当前装备
	var old_uid = equipped[slot]
	if not old_uid.is_empty():
		pass # 旧装备已在背包中
	equipped[slot] = uid
	return true

func unequip(slot: String) -> bool:
	var uid = equipped[slot]
	if uid.is_empty():
		return false
	# 将卸下的装备放回背包
	var eq = get_equipment_by_uid(uid)
	if not eq.is_empty():
		# 装备已在背包中（不应该发生），但为安全起见
		pass
	equipped[slot] = ""
	print("[Unequip] %s from slot=%s" % [uid, slot])
	return true

func get_equipped_stats() -> Dictionary:
	var total := {"atk": 0, "def": 0, "max_hp": 0}
	for slot in equipped:
		var uid = equipped[slot]
		if uid.is_empty():
			continue
		var eq = get_equipment_by_uid(uid)
		if eq.is_empty():
			continue
		for key in total:
			total[key] += eq.get("base_stats", {}).get(key, 0)
	return total

func reset_for_battle() -> void:
	var stats = get_final_stats()
	current_hp = stats["max_hp"]
	current_mp = stats["max_mp"]

## 初始化默认基础属性（新游戏或兼容旧存档）
func init_default_primary_stats() -> void:
	primary_stats = {"STR": 10, "AGI": 10, "INT": 10}
	unallocated_points = 0
	_sync_base_stats()

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
	unallocated_points = 0
	print("[Migration] Migrated primary_stats: STR=%d, AGI=%d, INT=%d" % [primary_stats["STR"], primary_stats["AGI"], primary_stats["INT"]])
