extends Node

const SLOT_PATH_TEMPLATE = "user://save_slot_%d.json"
const MIGRATION_SOURCE = "user://save.json"

var active_slot: int = -1
var _pending_save: Dictionary = {}
var _save_dirty: bool = false
var _save_timer: float = 0.0
var _total_playtime: float = 0.0
const AUTO_SAVE_DELAY: float = 2.0

func _ready():
	_migrate_legacy_save()
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
	if active_slot > 0:
		_total_playtime += delta
	if _save_dirty:
		_save_timer -= delta
		if _save_timer <= 0:
			_save_dirty = false
			save_game()

func _slot_path(slot: int) -> String:
	return SLOT_PATH_TEMPLATE % slot

func _migrate_legacy_save():
	if FileAccess.file_exists(MIGRATION_SOURCE) and not FileAccess.file_exists(_slot_path(1)):
		DirAccess.copy_absolute(MIGRATION_SOURCE, _slot_path(1))
		DirAccess.remove_absolute(MIGRATION_SOURCE)

func set_active_slot(slot: int):
	active_slot = slot

func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func delete_slot(slot: int):
	var path = _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func get_slot_metadata(slot: int) -> Dictionary:
	var path = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data = json.data
	var level_sys = data.get("level_system", {})
	var player_data = data.get("player", {})
	var class_id = player_data.get("class_id", "warrior")
	var class_name = "战士"
	var class_sys = get_node_or_null("/root/ClassSystem")
	if class_sys:
		class_name = class_sys.get_class_data(class_id).get("name", "战士")
	var result = {
		"level": level_sys.get("level", 1),
		"class_name": class_name,
		"playtime": data.get("playtime", 0.0),
		"floor": data.get("floor", 1),
		"timestamp": data.get("timestamp", ""),
	}
	return result

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
	if active_slot < 0:
		return false
	return FileAccess.file_exists(_slot_path(active_slot))

func load_game():
	if active_slot < 0:
		_pending_save = {}
		return
	var path = _slot_path(active_slot)
	if not FileAccess.file_exists(path):
		_pending_save = {}
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_pending_save = {}
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_pending_save = {}
		return
	_pending_save = json.data
	_total_playtime = _pending_save.get("playtime", 0.0)

func apply_save_data():
	if _pending_save.is_empty() and has_save():
		load_game()
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
	if pd.has("class_id"):
		player.class_id = pd["class_id"]
	if pd.has("STR"):
		player.STR = pd["STR"]
		player.AGI = pd["AGI"]
		player.INT = pd["INT"]
	else:
		# v3 migration: estimate attributes from level
		var level_data = _pending_save.get("level_system", {})
		var saved_level = level_data.get("level", 1)
		var class_sys = get_node_or_null("/root/ClassSystem")
		if class_sys:
			var init = class_sys.get_init_stats(player.class_id)
			player.STR = init["STR"]
			player.AGI = init["AGI"]
			player.INT = init["INT"]
			for lv in range(2, saved_level + 1):
				class_sys.apply_level_up(player, player.class_id)
			# Restore level system to correct level
			var level_sys = get_node_or_null("/root/LevelSystem")
			if level_sys:
				level_sys.level = saved_level
	# hp restored after attributes (derived max_hp needed)
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
		var saved_equip = _pending_save["equipment"]
		for slot_name in equip_sys.equipped:
			if saved_equip.has(slot_name):
				equip_sys.equipped[slot_name] = saved_equip[slot_name]
		equip_sys.equipment_changed.emit()

	# Restore HP (after equipment loaded so max_hp is correct)
	if pd.has("hp"):
		player.hp = mini(pd["hp"], player.get_total_max_hp())
	if pd.has("mp"):
		player.mp = mini(pd["mp"], player.get_total_max_mp())
	if pd.has("auto_attack"):
		player.auto_attack = pd["auto_attack"]

	# Restore level system
	var level_sys = get_node_or_null("/root/LevelSystem")
	if level_sys and _pending_save.has("level_system"):
		level_sys.load_save_data(_pending_save["level_system"])

	# Restore spawn respawn state
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

	# Restore skill tree system
	var skill_tree_sys = get_node_or_null("/root/SkillTreeSystem")
	if skill_tree_sys and _pending_save.has("skill_tree"):
		skill_tree_sys.load_save_data(_pending_save["skill_tree"])

	# Restore honor system
	var honor_sys = get_node_or_null("/root/HonorSystem")
	if honor_sys and _pending_save.has("honor"):
		honor_sys.load_save_data(_pending_save["honor"])

	# Restore tutorial
	var tutorial_sys = get_tree().current_scene.get_node_or_null("TutorialSystem")
	if tutorial_sys:
		if _pending_save.get("tutorial_completed", false):
			tutorial_sys.skip_and_hide()
		elif _pending_save.has("tutorial_step") and _pending_save["tutorial_step"] > 0:
			tutorial_sys.resume_from_step(_pending_save["tutorial_step"])

	_pending_save = {}

func save_game():
	if active_slot < 0:
		return
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]

	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	var current_floor = 1
	if spawn_sys:
		current_floor = spawn_sys.current_floor

	var data = {
		"version": 4,
		"floor": current_floor,
		"playtime": _total_playtime,
		"timestamp": Time.get_datetime_string_from_system(),
		"player": {
			"class_id": player.class_id,
			"STR": player.STR,
			"AGI": player.AGI,
			"INT": player.INT,
			"hp": player.hp,
			"mp": player.mp,
			"gold": player.gold,
			"auto_attack": player.auto_attack,
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
			"helmet": null,
			"accessory": null,
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

	# Save skill tree system
	var skill_tree_sys = get_node_or_null("/root/SkillTreeSystem")
	if skill_tree_sys:
		data["skill_tree"] = skill_tree_sys.get_save_data()

	# Save honor system
	var honor_sys = get_node_or_null("/root/HonorSystem")
	if honor_sys:
		data["honor"] = honor_sys.get_save_data()

	var file = FileAccess.open(_slot_path(active_slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

	# Cloud sync (if logged in)
	_sync_to_cloud(data)

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

# --- Cloud Sync ---

func _sync_to_cloud(local_data: Dictionary):
	var auth = get_node_or_null("/root/AuthManager")
	var api = get_node_or_null("/root/APIClient")
	if not auth or not api or not auth.is_logged_in:
		return
	# Send save data to cloud
	var cloud_data = local_data.duplicate(true)
	cloud_data["username"] = auth.username
	api.update_player(auth.username, cloud_data)

func _try_load_from_cloud() -> Dictionary:
	var auth = get_node_or_null("/root/AuthManager")
	var api = get_node_or_null("/root/APIClient")
	if not auth or not api or not auth.is_logged_in:
		return {}
	# Cloud load is async - for now return empty
	# In production, this would wait for the response
	return {}

func has_cloud_data() -> bool:
	var auth = get_node_or_null("/root/AuthManager")
	return auth != null and auth.is_logged_in
