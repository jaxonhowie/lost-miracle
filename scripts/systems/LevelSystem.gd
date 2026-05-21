extends Node

signal leveled_up(new_level: int)
signal xp_gained(amount: int, total: int)

var level: int = 1
var xp: int = 0

# Level N requires N*50 + 20 XP
func xp_for_level(lvl: int) -> int:
	return lvl * 50 + 20

func xp_to_next_level() -> int:
	return xp_for_level(level)

func add_xp(amount: int):
	xp += amount
	xp_gained.emit(amount, xp)
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		_apply_level_up()
		leveled_up.emit(level)

func _apply_level_up():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	player.attack += 2
	player.defense += 1
	player.max_hp += 15
	player.hp = player.get_total_max_hp()
	AudioManager.play_sfx("res://assets/audio/sfx_levelup.ogg")

func get_save_data() -> Dictionary:
	return { "level": level, "xp": xp }

func load_save_data(data: Dictionary):
	level = data.get("level", 1)
	xp = data.get("xp", 0)
