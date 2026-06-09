class_name Equipment
extends RefCounted

## 装备生成器

## 品质 -> 词条数量
const QUALITY_AFFIX_COUNT = {
	"normal": 1,
	"fine": 2,
	"rare": 3,
	"epic": 4,
	"legendary": 5,
}

## 品质颜色
const QUALITY_COLORS = {
	"normal": Color.WHITE,
	"fine": Color.GREEN,
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.6, 0.2, 0.9),
	"legendary": Color(1.0, 0.65, 0.0),
}

## 怪物类型 -> 可掉落品质
const DROP_QUALITY_BY_TYPE = {
	"normal": ["normal", "fine", "rare"],
	"elite": ["fine", "rare", "epic"],
	"boss": ["rare", "epic", "legendary"],
}

## 品质权重
const QUALITY_WEIGHTS = {
	"normal": {"normal": 70, "fine": 25, "rare": 5},
	"elite": {"fine": 50, "rare": 35, "epic": 15},
	"boss": {"rare": 40, "epic": 40, "legendary": 20},
}

## 特效解锁的强化等级阈值
const EFFECT_TIER_LEVELS = {
	"tier1": 5,
	"tier2": 7,
	"tier3": 8,
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
		# 解析 "eq_时间戳_序号" 格式
		var parts = uid.split("_")
		if parts.size() >= 3:
			var num = parts[2].to_int()
			if num > max_num:
				max_num = num
	_uid_counter = maxi(_uid_counter, max_num)

static func roll_quality(monster_type: String) -> String:
	var weights = QUALITY_WEIGHTS.get(monster_type, QUALITY_WEIGHTS["normal"])
	var total = 0
	for w in weights.values():
		total += w
	var roll = randi() % total
	var cumulative = 0
	for quality in weights:
		cumulative += weights[quality]
		if roll < cumulative:
			return quality
	return "normal"

static func generate_equipment(monster_type: String, slot_override: String = "") -> Dictionary:
	var quality = roll_quality(monster_type)
	var bases = DataManager.get_all_equipment_bases()
	if bases.is_empty():
		return {}
	# 按槽位过滤
	if not slot_override.is_empty():
		bases = bases.filter(func(b): return b.get("slot", "") == slot_override)
	if bases.is_empty():
		bases = DataManager.get_all_equipment_bases()
	var base = bases[randi() % bases.size()]
	var affix_count = QUALITY_AFFIX_COUNT.get(quality, 1)
	var affixes := []
	for i in affix_count:
		var affix_template = DataManager.get_random_affix()
		if affix_template.is_empty():
			continue
		var value = randf_range(affix_template.get("min", 0), affix_template.get("max", 0))
		if affix_template.get("stat", "") in ["crit_rate", "crit_dmg", "lifesteal", "skill_damage", "undead_damage", "damage_reduce"]:
			value = snappedf(value, 0.01)
		else:
			value = int(value)
		affixes.append({"stat": affix_template.get("stat", ""), "value": value})
	var eq = {
		"uid": generate_uid(),
		"base_id": base.get("id", ""),
		"name": _generate_name(quality, base.get("name", "")),
		"slot": base.get("slot", ""),
		"type": base.get("type", ""),
		"class_req": base.get("class_req", ""),
		"dual_wield": base.get("dual_wield", false),
		"quality": quality,
		"enhance_level": 0,
		"base_stats": base.get("base_stats", {}).duplicate(),
		"affixes": affixes,
		"set_id": base.get("set_id", ""),
		"effects": base.get("effects", {}).duplicate(true),
	}
	return eq

static func _generate_name(quality: String, base_name: String) -> String:
	match quality:
		"normal":
			return base_name
		"fine":
			return "精良的" + base_name
		"rare":
			return "稀有的" + base_name
		"epic":
			return "史诗" + base_name
		"legendary":
			return "传说" + base_name
	return base_name

static func get_quality_color(quality: String) -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE)

## ---------- 职业限制 ----------

## 检查装备是否有职业限制
static func has_class_restriction(eq: Dictionary) -> bool:
	var class_req = eq.get("class_req", "")
	return class_req != null and class_req != ""

## 检查玩家职业是否可以装备该装备
## class_req 为 null 或空字符串表示无限制
static func can_class_equip(eq: Dictionary, player_class: String) -> bool:
	var class_req = eq.get("class_req", "")
	if class_req == null or class_req == "":
		return true
	return class_req == player_class

## 获取职业限制的中文描述
static func get_class_req_text(eq: Dictionary) -> String:
	var class_req = eq.get("class_req", "")
	if class_req == null or class_req == "":
		return "无限制"
	match class_req:
		"warrior":
			return "战士专属"
		"ranger":
			return "游侠专属"
		"mage":
			return "法师专属"
		_:
			return class_req

## ---------- 特效系统 ----------

## 获取当前激活的特效等级
static func get_active_effect_tier(enhance_level: int) -> String:
	if enhance_level >= EFFECT_TIER_LEVELS["tier3"]:
		return "tier3"
	elif enhance_level >= EFFECT_TIER_LEVELS["tier2"]:
		return "tier2"
	elif enhance_level >= EFFECT_TIER_LEVELS["tier1"]:
		return "tier1"
	return ""

## 获取当前激活的所有特效（累积：tier1 + tier2 + tier3）
static func get_active_effects(eq: Dictionary) -> Dictionary:
	var enhance_level = eq.get("enhance_level", 0)
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

## 获取指定特效等级的解锁状态
static func is_effect_tier_unlocked(eq: Dictionary, tier: String) -> bool:
	var enhance_level = eq.get("enhance_level", 0)
	var required = EFFECT_TIER_LEVELS.get(tier, 99)
	return enhance_level >= required

## 获取特效的显示文本列表
static func get_effect_descriptions(eq: Dictionary) -> Array:
	var effects_data = eq.get("effects", {})
	if effects_data.is_empty():
		return []
	var enhance_level = eq.get("enhance_level", 0)
	var descriptions := []
	for tier_key in ["tier1", "tier2", "tier3"]:
		var tier_effects = effects_data.get(tier_key, {})
		if tier_effects.is_empty():
			continue
		var required = EFFECT_TIER_LEVELS.get(tier_key, 99)
		var unlocked = enhance_level >= required
		var tier_label = "+%d 解锁" % required
		var status = "[已激活]" if unlocked else "[未激活]"
		for stat in tier_effects:
			var value = tier_effects[stat]
			var stat_text = _format_effect_stat(stat, value)
			descriptions.append("%s %s %s (%s)" % [status, tier_label, stat_text, _get_tier_display_name(tier_key)])
	return descriptions

## 获取指定特效等级的显示名称
static func _get_tier_display_name(tier: String) -> String:
	match tier:
		"tier1":
			return "初级特效"
		"tier2":
			return "二级特效"
		"tier3":
			return "终极特效"
		_:
			return tier

## 格式化特效属性显示
static func _format_effect_stat(stat: String, value: Variant) -> String:
	match stat:
		"atk":
			return "攻击力 +%s" % str(value)
		"def":
			return "防御力 +%s" % str(value)
		"max_hp":
			return "最大生命 +%s" % str(value)
		"spd":
			return "速度 +%s" % str(value)
		"crit_rate":
			return "暴击率 +%s%%" % str(snappedf(value * 100, 0.1))
		"crit_dmg":
			return "暴击伤害 +%s%%" % str(snappedf(value * 100, 0.1))
		"lifesteal":
			return "吸血 +%s%%" % str(snappedf(value * 100, 0.1))
		"dodge":
			return "闪避 +%s%%" % str(snappedf(value * 100, 0.1))
		"undead_damage":
			return "亡灵伤害 +%s%%" % str(snappedf(value * 100, 0.1))
		"undead_damage_reduce":
			return "亡灵减伤 +%s%%" % str(snappedf(value * 100, 0.1))
		"undead_lifesteal":
			return "亡灵吸血 +%s%%" % str(snappedf(value * 100, 0.1))
		"damage_reduce":
			return "受伤减少 %s%%" % str(snappedf(value * 100, 0.1))
		"damage_boost_on_kill":
			return "击杀后攻击 +%s%% (3回合)" % str(snappedf(value * 100, 0.1))
		"skill_damage":
			return "技能伤害 +%s%%" % str(snappedf(value * 100, 0.1))
		"thorns_percent":
			return "荆棘反伤 %s%%" % str(snappedf(value * 100, 0.1))
		"block_chance":
			return "格挡几率 %s%%" % str(snappedf(value * 100, 0.1))
		"blood_rage_below_30hp":
			return "低于30%%血量攻击 +%s%%" % str(snappedf(value * 100, 0.1))
		"crit_guarantee_after_crit":
			return "暴击后下次必暴"
		"crit_guarantee_after_kill":
			return "击杀后下次必暴"
		"execute_below_20hp":
			return "目标低于20%%血量直接斩杀"
		_:
			return "%s: %s" % [stat, str(value)]

## 将特效属性应用到最终属性
## 应该在 _apply_equipment_stats 之后调用
static func apply_effects_to_stats(stats: Dictionary, eq: Dictionary) -> void:
	var active_effects = get_active_effects(eq)
	for stat in active_effects:
		var value = active_effects[stat]
		# 布尔类型的特效不直接加属性，在战斗逻辑中处理
		if value is bool:
			continue
		# 百分比类属性
		if stat in ["crit_rate", "crit_dmg", "lifesteal", "dodge", "undead_damage",
					"undead_damage_reduce", "undead_lifesteal", "damage_reduce",
					"damage_boost_on_kill", "skill_damage", "thorns_percent",
					"block_chance", "blood_rage_below_30hp"]:
			stats[stat] = stats.get(stat, 0.0) + value
		else:
			# 数值类属性
			stats[stat] = stats.get(stat, 0) + value

## 检查装备是否有任何布尔特效被激活
static func get_active_bool_effects(eq: Dictionary) -> Array:
	var active_effects = get_active_effects(eq)
	var bool_effects := []
	for stat in active_effects:
		if active_effects[stat] is bool and active_effects[stat]:
			bool_effects.append(stat)
	return bool_effects
