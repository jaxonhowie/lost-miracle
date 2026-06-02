extends Node

signal match_found(opponent: Dictionary)
signal battle_result(won: bool, opponent: Dictionary, honor_change: int)

var is_matching: bool = false
var _match_timer: float = 0.0
const MATCH_DURATION: float = 3.0  # seconds to find match

func start_matchmaking():
	if is_matching:
		return
	is_matching = true
	_match_timer = MATCH_DURATION

func cancel_matchmaking():
	is_matching = false

func _process(delta):
	if not is_matching:
		return
	_match_timer -= delta
	if _match_timer <= 0:
		is_matching = false
		_generate_opponent()

func _generate_opponent():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]

	var honor_sys = get_node_or_null("/root/HonorSystem")
	var player_honor = honor_sys.honor if honor_sys else 0
	var level_sys = get_node_or_null("/root/LevelSystem")
	var player_level = level_sys.level if level_sys else 1

	# Generate opponent near player's level and honor
	var opp_level = maxi(1, player_level + randi_range(-3, 3))
	var opp_honor = clampi(player_honor + randi_range(-200, 200), -1000, 1000)

	var class_names = ["warrior", "ranger", "assassin", "mage", "elven"]
	var opp_class = class_names[randi() % class_names.size()]

	var opponent = {
		"name": _generate_name(),
		"class": opp_class,
		"level": opp_level,
		"honor": opp_honor,
		"hp": 100 + opp_level * 15,
		"attack": 10 + opp_level * 3,
		"defense": 5 + opp_level * 2,
		"crit_rate": 0.1 + opp_level * 0.005,
		"crit_damage": 1.5,
		"speed": 100 + opp_level * 2,
	}
	match_found.emit(opponent)

func resolve_battle(opponent: Dictionary) -> Dictionary:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return {"won": false, "honor_change": 0}
	var player = players[0]

	# Get player stats
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	var stats = equip_sys.get_total_stats() if equip_sys else {}
	var class_sys = get_node_or_null("/root/ClassSystem")
	var derived = class_sys.compute_derived_stats() if class_sys else {}

	var player_hp = player.get_total_max_hp()
	var player_atk = player.get_total_attack()
	var player_def = player.get_total_defense()
	var player_crit = player.get_total_crit_rate()
	var player_crit_dmg = player.get_total_crit_damage()

	# Simulate 30 rounds of combat
	var p_hp = player_hp
	var o_hp = opponent["hp"]
	var p_atk = player_atk
	var o_atk = opponent["attack"]
	var p_def = player_def
	var o_def = opponent["defense"]

	for round in 30:
		# Player attacks
		var p_dmg = maxi(1, p_atk - o_def)
		if randf() < player_crit:
			p_dmg = int(p_dmg * player_crit_dmg)
		o_hp -= p_dmg

		if o_hp <= 0:
			break

		# Opponent attacks
		var o_dmg = maxi(1, o_atk - p_def)
		if randf() < opponent.get("crit_rate", 0.1):
			o_dmg = int(o_dmg * opponent.get("crit_damage", 1.5))
		p_hp -= o_dmg

		if p_hp <= 0:
			break

	# Determine winner (HP advantage breaks ties)
	var won = o_hp <= 0 or (p_hp > 0 and p_hp > o_hp)

	# Calculate honor change
	var honor_sys = get_node_or_null("/root/HonorSystem")
	var honor_change = 0
	if honor_sys:
		var player_honor = honor_sys.honor
		var opp_honor = opponent["honor"]
		if won:
			# Win against higher honor = more gain
			honor_change = 100 if opp_honor > player_honor else 50
			honor_sys.add_honor(honor_change, "PvP胜利")
		else:
			# Lose against lower honor = more loss
			honor_change = -200 if opp_honor < player_honor else -100
			honor_sys.add_honor(honor_change, "PvP失败")

	battle_result.emit(won, opponent, honor_change)

	return {
		"won": won,
		"honor_change": honor_change,
		"player_hp_left": maxi(0, p_hp),
		"opponent_hp_left": maxi(0, o_hp),
	}

func _generate_name() -> String:
	var prefixes = ["暗影", "烈焰", "寒冰", "雷霆", "圣光", "虚空", "幽灵", "血色"]
	var suffixes = ["骑士", "猎手", "刺客", "法师", "战士", "游侠", "召唤师", "守卫"]
	return prefixes[randi() % prefixes.size()] + suffixes[randi() % suffixes.size()]
