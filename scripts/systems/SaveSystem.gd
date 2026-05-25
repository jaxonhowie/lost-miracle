extends Node

const SAVE_PATH = "user://save.json"

var _pending_save: Dictionary = {}
var _save_dirty: bool = false
var _save_timer: float = 0.0
const AUTO_SAVE_DELAY: float = 2.0

func _ready():
	load_game()
	# Connect auto-save signals
	var inv = get_node_or_null("/root/InventorySystem")
	if inv:
		inv.inventory_changed.connect(_mark_dirty)
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		equip_sys.equipment_changed.connect(_mark_dirty)
	var enhance_sys = get_node_or_null("/root/EnhanceSystem")
	if enhance_sys:
		enhance_sys.enhance_result.connect(_on_enhance_result)
	var drop_sys = get_node_or_null("/root/DropSystem")
	if drop_sys:
		drop_sys.item_dropped.connect(_on_item_dropped)
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		talent_sys.talent_learned.connect(_on_talent_learned)

func _process(delta):
	if _save_dirty:
		_save_timer -= delta
		if _save_timer <= 0:
			_save_dirty = false
			save_game()

func _mark_dirty():
	_save_dirty = true
	_save_timer = AUTO_SAVE_DELAY

func _on_enhance_result(_uid: String, _success: bool, _new_level: int):
	_mark_dirty()

func _on_talent_learned(_talent_id: String, _new_rank: int):
	_mark_dirty()

func _on_item_dropped(item_id: String, _count: int, _position: Vector2):
	if item_id == "gold":
		_mark_dirty()

func on_monster_died():
	_mark_dirty()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game():
	if not has_save():
		_pending_save = {}
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_pending_save = {}
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_pending_save = {}
		return
	_pending_save = json.data

func apply_save_data():
	if _pending_save.is_empty():
		return

	# Restore floor
	var saved_floor = _pending_save.get("floor", 1)
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	if spawn_sys and spawn_sys.current_floor != saved_floor:
		spawn_sys.switch_floor(saved_floor)

	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]

	# Restore player stats
	var pd = _pending_save.get("player", {})
	if pd.has("hp"):
		player.hp = pd["hp"]
	if pd.has("max_hp"):
		player.max_hp = pd["max_hp"]
	if pd.has("attack"):
		player.attack = pd["attack"]
	if pd.has("defense"):
		player.defense = pd["defense"]
	if pd.has("crit_rate"):
		player.crit_rate = pd["crit_rate"]
	if pd.has("crit_damage"):
		player.crit_damage = pd["crit_damage"]
	if pd.has("gold"):
		player.gold = pd["gold"]
	if pd.has("position"):
		player.global_position = Vector2(pd["position"]["x"], pd["position"]["y"])

	# Restore inventory
	var inv = get_node_or_null("/root/InventorySystem")
	if inv and _pending_save.has("inventory"):
		inv.inventory = _pending_save["inventory"]
		inv.inventory_changed.emit()
	if inv and _pending_save.has("quick_use_slot"):
		inv.quick_use_slot = _pending_save["quick_use_slot"]

	# Restore equipment
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys and _pending_save.has("equipment"):
		equip_sys.equipped = _pending_save["equipment"]
		equip_sys.equipment_changed.emit()

	# Restore level system
	var level_sys = get_node_or_null("/root/LevelSystem")
	if level_sys and _pending_save.has("level_system"):
		level_sys.load_save_data(_pending_save["level_system"])

	# Restore spawn respawn state
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	if spawn_sys and _pending_save.has("spawn_respawn"):
		spawn_sys.apply_respawn_state(_pending_save["spawn_respawn"])

	# Restore achievement system
	var ach_sys = get_node_or_null("/root/AchievementSystem")
	if ach_sys and _pending_save.has("achievements"):
		ach_sys.load_save_data(_pending_save["achievements"])

	# Restore quest system
	var quest_sys = get_node_or_null("/root/QuestSystem")
	if quest_sys and _pending_save.has("quests"):
		quest_sys.load_save_data(_pending_save["quests"])

	# Restore talent system
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys and _pending_save.has("talent_system"):
		talent_sys.load_save_data(_pending_save["talent_system"])

	# Restore tutorial
	var tutorial_sys = get_tree().current_scene.get_node_or_null("TutorialSystem")
	if tutorial_sys:
		if _pending_save.get("tutorial_completed", false):
			tutorial_sys.skip_and_hide()
		elif _pending_save.has("tutorial_step") and _pending_save["tutorial_step"] > 0:
			tutorial_sys.resume_from_step(_pending_save["tutorial_step"])

	_pending_save = {}

func save_game():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]

	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	var current_floor = 1
	if spawn_sys:
		current_floor = spawn_sys.current_floor

	var data = {
		"version": 3,
		"floor": current_floor,
		"player": {
			"hp": player.hp,
			"max_hp": player.max_hp,
			"attack": player.attack,
			"defense": player.defense,
			"crit_rate": player.crit_rate,
			"crit_damage": player.crit_damage,
			"gold": player.gold,
			"position": {
				"x": player.global_position.x,
				"y": player.global_position.y,
			},
		},
		"inventory": [],
		"quick_use_slot": "",
		"equipment": {
			"weapon": null,
			"armor": null,
			"boots": null,
			"ring": null,
		},
		"spawn_respawn": {},
		"level_system": {},
	}

	var level_sys = get_node_or_null("/root/LevelSystem")
	if level_sys:
		data["level_system"] = level_sys.get_save_data()

	var inv = get_node_or_null("/root/InventorySystem")
	if inv:
		data["inventory"] = inv.inventory
		data["quick_use_slot"] = inv.quick_use_slot

	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		data["equipment"] = equip_sys.equipped

	if spawn_sys:
		data["spawn_respawn"] = spawn_sys.get_respawn_state()

	# Save achievement system
	var ach_sys = get_node_or_null("/root/AchievementSystem")
	if ach_sys:
		data["achievements"] = ach_sys.get_save_data()

	# Save quest system
	var quest_sys = get_node_or_null("/root/QuestSystem")
	if quest_sys:
		data["quests"] = quest_sys.get_save_data()

	# Save tutorial state
	var tutorial_sys = get_tree().current_scene.get_node_or_null("TutorialSystem")
	if tutorial_sys:
		data["tutorial_completed"] = tutorial_sys.is_completed
		data["tutorial_step"] = tutorial_sys._current_step_index

	# Save talent system
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		data["talent_system"] = talent_sys.get_save_data()

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func respawn_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]

	if _pending_save.is_empty() and has_save():
		load_game()

	if _pending_save.is_empty():
		# No save data, just reset HP
		player.hp = player.get_total_max_hp()
		player.is_dead = false
		player.get_node("CollisionShape2D").disabled = false
		player.hurtbox.monitoring = true
		return

	var pd = _pending_save.get("player", {})
	if pd.has("position"):
		player.global_position = Vector2(pd["position"]["x"], pd["position"]["y"])
	player.hp = player.get_total_max_hp()

	player.is_dead = false
	player.get_node("CollisionShape2D").disabled = false
	player.hurtbox.monitoring = true
	player.velocity = Vector2.ZERO

	_pending_save = {}
