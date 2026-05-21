extends Node

# Floor expected levels and multipliers
const FLOOR_DATA: Dictionary = {
	1: { "expected_level": 1, "multiplier": 1.0 },
	2: { "expected_level": 5, "multiplier": 1.4 },
}

# Every N levels above expected, add bonus
const LEVEL_STEP: int = 3
const LEVEL_BONUS: float = 0.08
const MAX_LEVEL_BONUS: float = 0.48  # cap at 6 steps

# Drop rate bonus
const DROP_BONUS_PER_STEP: float = 0.025
const MAX_DROP_BONUS: float = 0.15

func get_stats(base_hp: int, base_attack: int, base_defense: int, base_xp: int) -> Dictionary:
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	var level_sys = get_node_or_null("/root/LevelSystem")
	if not spawn_sys or not level_sys:
		return { "hp": base_hp, "attack": base_attack, "defense": base_defense, "xp": base_xp }

	var floor_num: int = spawn_sys.current_floor
	var floor_info: Dictionary = FLOOR_DATA.get(floor_num, FLOOR_DATA[1])
	var floor_mult: float = floor_info["multiplier"]
	var expected_lvl: int = floor_info["expected_level"]

	var player_level: int = level_sys.level
	var level_delta: int = maxi(0, player_level - expected_lvl)
	var steps: int = level_delta / LEVEL_STEP
	var level_bonus: float = minf(steps * LEVEL_BONUS, MAX_LEVEL_BONUS)

	var total_mult: float = floor_mult * (1.0 + level_bonus)

	return {
		"hp": int(base_hp * total_mult),
		"attack": int(base_attack * total_mult),
		"defense": int(base_defense * total_mult),
		"xp": int(base_xp * total_mult),
	}

func get_drop_bonus() -> float:
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	var level_sys = get_node_or_null("/root/LevelSystem")
	if not spawn_sys or not level_sys:
		return 0.0

	var floor_num: int = spawn_sys.current_floor
	var floor_info: Dictionary = FLOOR_DATA.get(floor_num, FLOOR_DATA[1])
	var expected_lvl: int = floor_info["expected_level"]

	var player_level: int = level_sys.level
	var level_delta: int = maxi(0, player_level - expected_lvl)
	var steps: int = level_delta / LEVEL_STEP
	return minf(steps * DROP_BONUS_PER_STEP, MAX_DROP_BONUS)
