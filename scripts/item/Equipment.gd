class_name Equipment
extends RefCounted

## 装备生成器 — R2 风格强化/品阶/词条

## 强化成功率（+0→+1 到 +9→+10）：[普通强化石, 受祝福强化石]
const ENHANCE_RATES := [
	[1.00, 1.00],
	[1.00, 1.00],
	[1.00, 1.00],
	[0.30, 1.00],
	[0.28, 0.33],
	[0.20, 0.25],
	[0.18, 0.23],
	[0.15, 0.20],
	[0.13, 0.18],
	[0.10, 0.15],
]
const ENHANCE_COSTS := [50, 50, 50, 100, 100, 200, 200, 500, 500, 1000]
const MAX_ENHANCE_LEVEL := 10

## 强化等级 -> 品质（视觉）
## +0=普通(白), +4=精良(蓝), +7=史诗(紫), +10=传说(橙)
static func get_quality_by_enhance(enhance_level: int) -> String:
	if enhance_level >= 10:
		return "legendary"
	elif enhance_level >= 7:
		return "epic"
	elif enhance_level >= 4:
		return "fine"
	else:
		return "normal"

## 品质颜色
const QUALITY_COLORS = {
	"normal": Color.WHITE,
	"fine": Color(0.3, 0.5, 1.0),
	"epic": Color(0.6, 0.2, 0.9),
	"legendary": Color(1.0, 0.65, 0.0),
}

## 品质名称
const QUALITY_NAMES = {
	"normal": "普通",
	"fine": "精良",
	"epic": "史诗",
	"legendary": "传说",
}

## 特效解锁的强化等级阈值
const EFFECT_TIER_LEVELS = {
	"tier1": 5,
	"tier2": 7,
	"tier3": 10,
}

static var _uid_counter: int = 0

static func generate_uid() -> String:
	_uid_counter += 1
	return "eq_%d_%d" % [Time.get_ticks_msec(), _uid_counter]

## 读档后调用，确保 uid 计数器不与已有装备冲突
static func sync_uid_counter(inventory: Array) -> void:
	var max_num = 0
	for eq in inventory:
		var uid: String = eq.get("uid", "")
		var parts = uid.split("_")
		if parts.size() >= 3:
			var num = parts[2].to_int()
			if num > max_num:
				max_num = num
	_uid_counter = maxi(_uid_counter, max_num)

## 按怪物类型加权随机掉落阶位（三档均可掉，概率不同）
static func roll_drop_tier(monster_type: String) -> String:
	var weights_cfg = DataManager.get_enhance_rules().get("drop_tier_weights", {})
	var weights: Dictionary = weights_cfg.get(monster_type, weights_cfg.get("normal", {}))
	if weights.is_empty():
		weights = {"vine": 70, "chain": 25, "plate": 5}
	var tiers := ["vine", "chain", "plate"]
	var total := 0
	for tier in tiers:
		total += int(weights.get(tier, 0))
	if total <= 0:
		return "vine"
	var roll = randi() % total
	var cumulative := 0
	for tier in tiers:
		cumulative += int(weights.get(tier, 0))
		if roll < cumulative:
			return tier
	return "vine"

## 从底材 ID 创建 +0 装备（新手装/奖励）
static func create_from_base(base_id: String) -> Dictionary:
	var base = DataManager.get_equipment_base(base_id)
	if base.is_empty():
		return {}
	return _build_equipment_instance(base, "normal", 0, false)

## 生成装备（按怪物类型加权随机阶位 + 随机词条）
static func generate_equipment(monster_type: String, slot_override: String = "") -> Dictionary:
	var tier = roll_drop_tier(monster_type)
	var bases = DataManager.get_all_equipment_bases()
	bases = bases.filter(func(b): return b.get("drop_tier", "") == tier)
	if bases.is_empty():
		return {}
	if not slot_override.is_empty():
		bases = bases.filter(func(b): return b.get("slot", "") == slot_override)
	if bases.is_empty():
		return {}
	var base = bases[randi() % bases.size()]
	var rules = DataManager.get_enhance_rules()
	var affix_cfg = rules.get("affix_count", {})
	var affix_count := 0
	match monster_type:
		"boss":
			affix_count = randi_range(1, int(affix_cfg.get("boss", 2)))
		"elite":
			affix_count = int(affix_cfg.get("elite", 1))
		_:
			affix_count = int(affix_cfg.get("normal", 0))
	var is_blessed := monster_type == "boss" and randf() < float(rules.get("blessed_equipment_on_drop", 0.10))
	return _build_equipment_instance(base, monster_type, affix_count, is_blessed)

static func _build_equipment_instance(base: Dictionary, monster_type: String, affix_count: int, is_blessed: bool) -> Dictionary:
	var rules = DataManager.get_enhance_rules()
	return {
		"uid": generate_uid(),
		"base_id": base.get("id", ""),
		"name": base.get("name", "未知装备"),
		"slot": base.get("slot", ""),
		"type": base.get("type", ""),
		"class_req": base.get("class_req", ""),
		"dual_wield": base.get("dual_wield", false),
		"grade": _roll_grade(monster_type, base),
		"safe_enhance_until": int(base.get("safe_enhance_until", rules.get("default_safe_until", 3))),
		"is_blessed": is_blessed,
		"quality": "normal",
		"enhance_level": 0,
		"base_stats": base.get("base_stats", {}).duplicate(),
		"affixes": roll_affixes(affix_count),
		"set_id": base.get("set_id", ""),
		"effects": base.get("effects", {}).duplicate(true),
	}

static func _roll_grade(monster_type: String, _base: Dictionary) -> String:
	match monster_type:
		"boss":
			return "unique"
		"elite":
			return "rare"
		"normal":
			if randf() < 0.15:
				return "advanced"
			return "normal"
		_:
			return "normal"

## 根据强化等级获取品质颜色
static func get_quality_color(quality: String) -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE)

## 获取品质中文名
static func get_quality_name(quality: String) -> String:
	return QUALITY_NAMES.get(quality, "普通")

static func get_quality_multiplier(quality: String) -> float:
	match quality:
		"fine": return 1.15
		"epic": return 1.60
		"legendary": return 1.85
		_: return 1.0

## ---------- R2 品阶 ----------

static func get_grade_multiplier(grade: String) -> float:
	var data = DataManager.get_grade(grade)
	return float(data.get("stat_mult", 1.0))

static func get_grade_name(grade: String) -> String:
	return DataManager.get_grade(grade).get("name", "普通")

static func get_grade_color(grade: String) -> Color:
	var hex = DataManager.get_grade(grade).get("color", "#cccccc")
	return Color.from_string(hex, Color.WHITE)

## ---------- 随机词条 ----------

static func roll_affixes(count: int) -> Array:
	if count <= 0:
		return []
	var pool: Array = DataManager.get_affixes()
	if pool.is_empty():
		return []
	var available = pool.duplicate()
	var picked: Array = []
	for _i in count:
		if available.is_empty():
			break
		var idx = randi() % available.size()
		var affix_def: Dictionary = available[idx]
		available.remove_at(idx)
		var stat: String = affix_def.get("stat", "")
		var value: Variant
		if stat in ["crit_rate", "crit_dmg", "lifesteal", "skill_damage", "undead_damage", "damage_reduce"]:
			value = randf_range(float(affix_def.get("min", 0)), float(affix_def.get("max", 0)))
		else:
			value = randi_range(int(affix_def.get("min", 0)), int(affix_def.get("max", 0)))
		picked.append({
			"id": affix_def.get("id", ""),
			"name": affix_def.get("name", ""),
			"stat": stat,
			"value": value,
		})
	return picked

static func apply_affixes_to_stats(stats: Dictionary, eq: Dictionary) -> void:
	for affix in eq.get("affixes", []):
		var stat: String = affix.get("stat", "")
		var value = affix.get("value", 0)
		if stat.is_empty():
			continue
		if stat in ["crit_rate", "crit_dmg", "lifesteal", "dodge", "undead_damage",
				"undead_damage_reduce", "undead_lifesteal", "damage_reduce",
				"damage_boost_on_kill", "skill_damage", "thorns_percent",
				"block_chance", "blood_rage_below_30hp"]:
			stats[stat] = stats.get(stat, 0.0) + float(value)
		elif stat == "spd":
			stats["atk_spd"] = stats.get("atk_spd", 1.0) + float(value) * 0.02
		else:
			stats[stat] = stats.get(stat, 0) + int(value)

## ---------- R2 强化（含损毁） ----------

static func get_safe_enhance_until(eq: Dictionary) -> int:
	return int(eq.get("safe_enhance_until", DataManager.get_enhance_rules().get("default_safe_until", 3)))

static func get_break_risk_text(eq: Dictionary, use_blessed_stone: bool) -> String:
	var level = int(eq.get("enhance_level", 0))
	var rules = DataManager.get_enhance_rules()
	var break_from = int(rules.get("break_from_level", 4))
	if level + 1 < break_from:
		return ""
	if use_blessed_stone:
		return "受祝福强化石：失败不损毁装备"
	var chance = float(rules.get("break_chance_normal_scroll", 0.35)) * 100.0
	var text = "警告：失败有 %.0f%% 概率损毁装备！" % chance
	if eq.get("is_blessed", false):
		var save = float(rules.get("blessed_equipment_save_chance", 0.5)) * 100.0
		text += " 祝福装备可 %.0f%% 保留。" % save
	return text

## 执行强化判定（材料需由调用方预先扣除）
## 返回: {success, broken, new_level, message, gained_blessed}
static func roll_enhance(eq: Dictionary, use_blessed_stone: bool) -> Dictionary:
	var level = int(eq.get("enhance_level", 0))
	if level >= MAX_ENHANCE_LEVEL:
		return {"success": false, "broken": false, "new_level": level, "message": "已达最高强化等级", "gained_blessed": false}
	var rates = ENHANCE_RATES[level]
	var rate = rates[1] if use_blessed_stone else rates[0]
	var rules = DataManager.get_enhance_rules()
	if randf() < rate:
		var new_level = level + 1
		eq["enhance_level"] = new_level
		var msg = "强化成功！+%d" % new_level
		var gained_blessed = false
		if new_level >= 7 and not eq.get("is_blessed", false):
			if randf() < float(rules.get("blessed_equipment_on_enhance_plus7", 0.15)):
				eq["is_blessed"] = true
				gained_blessed = true
				msg += "  装备获得祝福！"
		var old_q = get_quality_by_enhance(level)
		var new_q = get_quality_by_enhance(new_level)
		if new_q != old_q:
			msg += "  品质提升: %s" % get_quality_name(new_q)
		return {"success": true, "broken": false, "new_level": new_level, "message": msg, "gained_blessed": gained_blessed}
	# 失败
	var broken = _roll_break_on_fail(eq, use_blessed_stone)
	var fail_msg = "强化失败...材料已消耗"
	if broken:
		fail_msg = "强化失败！装备已损毁..."
	elif eq.get("is_blessed", false):
		fail_msg = "强化失败...祝福之力保住了装备"
	return {"success": false, "broken": broken, "new_level": level, "message": fail_msg, "gained_blessed": false}

static func _roll_break_on_fail(eq: Dictionary, use_blessed_stone: bool) -> bool:
	var level = int(eq.get("enhance_level", 0))
	var rules = DataManager.get_enhance_rules()
	var break_from = int(rules.get("break_from_level", 4))
	if level + 1 < break_from:
		return false
	if use_blessed_stone:
		return false
	var safe_until = get_safe_enhance_until(eq)
	if level <= safe_until:
		return false
	var break_chance = float(rules.get("break_chance_normal_scroll", 0.35))
	if randf() >= break_chance:
		return false
	if eq.get("is_blessed", false):
		return randf() >= float(rules.get("blessed_equipment_save_chance", 0.5))
	return true

## 强化扁平加值（与 PlayerData 属性计算一致）
static func calc_enhance_bonus(stat: String, level: int, slot: String) -> int:
	if level <= 0:
		return 0
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
		"armor", "helmet", "legs":
			if stat == "def" or stat == "max_hp":
				for i in range(1, level + 1):
					if i <= 5:
						bonus += 1
					elif i <= 7:
						bonus += 2
					else:
						bonus += 3
		"gloves", "ring", "necklace":
			if stat == "atk" or stat == "def" or stat == "max_hp":
				for i in range(1, level + 1):
					if i <= 5:
						bonus += 1
					elif i <= 7:
						bonus += 2
					else:
						bonus += 3
	return bonus

## 单条属性的有效值（品质倍率 + 强化加值）
static func calc_effective_stat_value(eq: Dictionary, stat: String, override_level: int = -1) -> Variant:
	var base_stats = eq.get("base_stats", {})
	if not base_stats.has(stat):
		return null
	var base_val = base_stats[stat]
	var level = override_level if override_level >= 0 else int(eq.get("enhance_level", 0))
	var slot = eq.get("slot", "")
	if stat in ["crit_rate", "crit_dmg", "lifesteal", "dodge", "hit", "skill_damage", "undead_damage", "damage_reduce", "atk_spd"]:
		return base_val
	if stat in ["atk", "def", "max_hp", "max_mp"]:
		var quality_mult = get_quality_multiplier(get_quality_by_enhance(level))
		var grade_mult = get_grade_multiplier(eq.get("grade", "normal"))
		return int(base_val * quality_mult * grade_mult) + calc_enhance_bonus(stat, level, slot)
	return base_val

## ---------- 职业限制 ----------

static func can_class_equip(eq: Dictionary, player_class: String) -> bool:
	var class_req = eq.get("class_req", "")
	if class_req == null or class_req == "":
		return true
	return class_req == player_class

## ---------- 特效系统 ----------

## 获取当前激活的所有特效（累积）
static func get_active_effects(eq: Dictionary) -> Dictionary:
	var enhance_level = int(eq.get("enhance_level", 0))
	var effects_data = eq.get("effects", {})
	if effects_data.is_empty():
		return {}
	var active := {}
	for tier_key in ["tier1", "tier2", "tier3"]:
		var required_level = EFFECT_TIER_LEVELS.get(tier_key, 99)
		if enhance_level >= required_level:
			var tier_effects = effects_data.get(tier_key, {})
			for stat in tier_effects:
				active[stat] = tier_effects[stat]
	return active

## 将特效属性应用到最终属性
static func apply_effects_to_stats(stats: Dictionary, eq: Dictionary) -> void:
	var active_effects = get_active_effects(eq)
	for stat in active_effects:
		var value = active_effects[stat]
		if value is bool:
			continue
		if stat in ["crit_rate", "crit_dmg", "lifesteal", "dodge", "hit", "atk_spd",
					"undead_damage", "undead_damage_reduce", "undead_lifesteal", "damage_reduce",
					"damage_boost_on_kill", "skill_damage", "thorns_percent",
					"block_chance", "blood_rage_below_30hp"]:
			stats[stat] = stats.get(stat, 0.0) + value
		else:
			stats[stat] = stats.get(stat, 0) + value
