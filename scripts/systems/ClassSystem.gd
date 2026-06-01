extends Node

const CLASSES: Dictionary = {
	"warrior": {
		"name": "战士",
		"primary": "STR",
		"base": { "STR": 10, "AGI": 5, "INT": 5 },
		"secondaries": ["AGI", "INT"],  # alternating: lv2→AGI, lv3→INT, lv4→AGI...
		"attack_type": "melee_physical",
		"description": "近战物理输出，高生命高防御"
	},
	"ranger": {
		"name": "弓箭手",
		"primary": "AGI",
		"base": { "STR": 5, "AGI": 10, "INT": 5 },
		"secondaries": ["INT", "STR"],
		"attack_type": "ranged_physical",
		"description": "远程物理输出，高暴击"
	},
	"assassin": {
		"name": "刺客",
		"primary": "AGI",
		"base": { "STR": 5, "AGI": 10, "INT": 5 },
		"secondaries": ["STR", "INT"],
		"attack_type": "melee_physical",
		"description": "近战物理输出，高暴击高速度"
	},
	"mage": {
		"name": "法师",
		"primary": "INT",
		"base": { "STR": 5, "AGI": 5, "INT": 10 },
		"secondaries": ["STR", "AGI"],
		"attack_type": "spell",
		"description": "法术输出，高技能伤害"
	}
}

var selected_class: String = "warrior"

func get_class_data(class_id: String) -> Dictionary:
	return CLASSES.get(class_id, CLASSES["warrior"])

func get_class_list() -> Array:
	return CLASSES.keys()

func compute_derived_stats(str_val: int, agi_val: int, int_val: int, equip: Dictionary, class_id: String) -> Dictionary:
	var class_data = get_class_data(class_id)
	var primary_stat = 0
	match class_data["primary"]:
		"STR": primary_stat = str_val
		"AGI": primary_stat = agi_val
		"INT": primary_stat = int_val

	var equip_atk = equip.get("attack", 0)
	var equip_def = equip.get("defense", 0)
	var equip_hp = equip.get("hp", 0)
	var equip_crit_rate = equip.get("crit_rate", 0.0)
	var equip_crit_damage = equip.get("crit_damage", 0.0)

	return {
		"attack": primary_stat / 3 + equip_atk,
		"max_hp": 100 + str_val * 5 + equip_hp,
		"defense": str_val / 3 + equip_def,
		"crit_rate": 0.05 + agi_val * 0.005 + equip_crit_rate,
		"crit_damage": 1.5 + equip_crit_damage,
		"attack_type": class_data["attack_type"],
	}

func apply_level_up(player: Node, class_id: String):
	var class_data = get_class_data(class_id)
	var level_sys = get_node_or_null("/root/LevelSystem")
	var new_level = level_sys.level if level_sys else 1

	# Primary stat: +1 per level
	match class_data["primary"]:
		"STR": player.STR += 1
		"AGI": player.AGI += 1
		"INT": player.INT += 1

	# Secondary stats: alternate starting from level 2
	if new_level >= 2:
		var sec_index = (new_level - 2) % 2
		var sec_stat = class_data["secondaries"][sec_index]
		match sec_stat:
			"STR": player.STR += 1
			"AGI": player.AGI += 1
			"INT": player.INT += 1

func get_init_stats(class_id: String) -> Dictionary:
	var class_data = get_class_data(class_id)
	return class_data["base"].duplicate()
