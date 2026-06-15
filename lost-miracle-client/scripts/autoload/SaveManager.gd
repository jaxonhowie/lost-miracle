extends Node

## 多存档管理 — user://saves/

const LEGACY_SAVE_PATH := "user://save.json"
const SAVES_DIR := "user://saves/"
const MANIFEST_PATH := "user://saves/manifest.json"
const DISPLAY_SLOT_COUNT := 3
const SLOT_WIDTH := 520
const SLOT_HEIGHT := 96

var current_save_id: String = ""

func _ready() -> void:
	_ensure_saves_dir()
	_migrate_legacy_save()

func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_absolute(SAVES_DIR)

func _save_path(save_id: String) -> String:
	return SAVES_DIR + save_id + ".json"

func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {"saves": []}
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		return {"saves": []}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {"saves": []}
	file.close()
	var data = json.data
	if data is Dictionary:
		return data
	return {"saves": []}

func _write_manifest(manifest: Dictionary) -> void:
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()

func _generate_save_id() -> String:
	return "save_%d" % int(Time.get_unix_time_from_system())

func _network_manager() -> Node:
	return get_node_or_null("/root/NetworkManager")

func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var manifest = _load_manifest()
	if not manifest.get("saves", []).is_empty():
		return
	var file = FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	var data = json.data
	file.close()
	if not data is Dictionary:
		return
	var save_id = _generate_save_id()
	var dest = FileAccess.open(_save_path(save_id), FileAccess.WRITE)
	if dest:
		dest.store_string(JSON.stringify(data, "\t"))
		dest.close()
	var p = data.get("player", {})
	var world = data.get("world", {})
	manifest["saves"] = [{
		"id": save_id,
		"player_class": p.get("class", "warrior"),
		"level": int(p.get("level", 1)),
		"last_login_at": int(Time.get_unix_time_from_system()),
		"current_dungeon_id": world.get("current_dungeon_id", "bone_crypt"),
	}]
	_write_manifest(manifest)
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove("save.json")

func get_display_slots() -> Array:
	var manifest = _load_manifest()
	var saves: Array = manifest.get("saves", []).duplicate()
	saves.sort_custom(func(a, b):
		return int(a.get("last_login_at", 0)) > int(b.get("last_login_at", 0))
	)
	var result := []
	for i in mini(DISPLAY_SLOT_COUNT, saves.size()):
		result.append({"empty": false, "meta": saves[i]})
	while result.size() < DISPLAY_SLOT_COUNT:
		result.append({"empty": true, "meta": {}})
	return result

func get_cloud_display_slots(characters: Array, max_slots: int = DISPLAY_SLOT_COUNT) -> Array:
	var result := []
	for ch in characters:
		if result.size() >= max_slots:
			break
		var char_id := ApiIds.from_value(ch.get("id", 0))
		result.append({
			"empty": false,
			"meta": {
				"id": SaveManager.find_local_save_id_for_character(char_id),
				"character_id": char_id,
				"name": str(ch.get("name", "")),
				"player_class": str(ch.get("playerClass", ch.get("player_class", "warrior"))),
				"level": int(ch.get("level", 1)),
				"last_login_at": int(ch.get("lastLoginAt", ch.get("last_login_at", 0))),
				"current_dungeon_id": str(ch.get("currentDungeonId", ch.get("current_dungeon_id", "bone_crypt"))),
				"save_version": int(ch.get("saveVersion", ch.get("save_version", 0))),
			},
		})
	var create_slots := maxi(0, max_slots - characters.size())
	for _i in create_slots:
		if result.size() >= max_slots:
			break
		result.append({"empty": true, "meta": {}})
	return result

func find_local_save_id_for_character(character_id: String) -> String:
	var cid := ApiIds.from_value(character_id)
	if cid.is_empty():
		return ""
	for s in _load_manifest().get("saves", []):
		if ApiIds.from_value(s.get("character_id", "")) == cid:
			return str(s.get("id", ""))
	return ""

func create_cache_for_character(character_id: String, char_meta: Dictionary, save_data: Dictionary) -> String:
	var save_id := _generate_save_id()
	current_save_id = save_id
	_apply_save_data(save_data)
	var file = FileAccess.open(_save_path(save_id), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
	update_manifest_for_character(character_id, char_meta, save_id)
	return save_id

func update_manifest_for_character(character_id: String, char_meta: Dictionary, save_id: String = "") -> void:
	var manifest = _load_manifest()
	var saves: Array = manifest.get("saves", [])
	var id = save_id if not save_id.is_empty() else current_save_id
	if id.is_empty():
		return
	var cid := ApiIds.from_value(character_id)
	var entry := {
		"id": id,
		"character_id": cid,
		"name": str(char_meta.get("name", "")),
		"player_class": str(char_meta.get("playerClass", char_meta.get("player_class", Game.player_class))),
		"level": int(char_meta.get("level", PlayerData.level)),
		"last_login_at": int(char_meta.get("lastLoginAt", char_meta.get("last_login_at", Time.get_unix_time_from_system()))),
		"current_dungeon_id": str(char_meta.get("currentDungeonId", char_meta.get("current_dungeon_id", Game.current_dungeon_id))),
	}
	var found := false
	for i in saves.size():
		if saves[i].get("id", "") == id or ApiIds.from_value(saves[i].get("character_id", "")) == cid:
			saves[i] = entry
			found = true
			break
	if not found:
		saves.append(entry)
	manifest["saves"] = saves
	_write_manifest(manifest)

func export_save_data() -> Dictionary:
	return _build_save_data()

func import_save_data(data: Dictionary) -> void:
	_apply_save_data(data)

func load_manifest() -> Dictionary:
	return _load_manifest()

func write_manifest(manifest: Dictionary) -> void:
	_write_manifest(manifest)

func remove_local_character(character_id: String, save_id: String = "") -> void:
	var cid := ApiIds.from_value(character_id)
	if not save_id.is_empty():
		var path = get_save_path(save_id)
		if FileAccess.file_exists(path):
			var dir = DirAccess.open(SAVES_DIR)
			if dir:
				dir.remove(save_id + ".json")
	var manifest = _load_manifest()
	var saves: Array = manifest.get("saves", [])
	saves = saves.filter(func(s):
		return ApiIds.from_value(s.get("character_id", "")) != cid and s.get("id", "") != save_id
	)
	manifest["saves"] = saves
	var dismissed: Array = manifest.get("dismissed_characters", [])
	dismissed = dismissed.filter(func(entry):
		return ApiIds.from_value(entry.get("character_id", "")) != cid
	)
	manifest["dismissed_characters"] = dismissed
	_write_manifest(manifest)
	if current_save_id == save_id:
		current_save_id = ""

func get_save_path(save_id: String) -> String:
	return _save_path(save_id)

func generate_save_id() -> String:
	return _generate_save_id()

func format_class_name(player_class: String) -> String:
	match player_class:
		"warrior": return "战士"
		"ranger": return "游侠"
		"assassin": return "刺客"
		"elven": return "精灵"
		_: return "未知职业"

func format_dungeon_name(dungeon_id: String) -> String:
	match dungeon_id:
		"bone_crypt": return "荒骨墓穴"
		"corrupt_swamp": return "腐蚀沼泽"
		"forge_ruins": return "赤焰锻造厂"
		"frozen_abyss": return "永冻深渊"
		_: return "未知地牢"

func format_last_login(unix_time: int) -> String:
	if unix_time <= 0:
		return "从未登录"
	var dt = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func create_new_save() -> bool:
	PlayerData.reset_for_new_game()
	Game.player_class = "warrior"
	Game.auto_battle = false
	Game.current_dungeon_id = "bone_crypt"
	Game.reset_dungeon()
	current_save_id = _generate_save_id()
	save_game()
	return true

func save_game() -> void:
	if current_save_id.is_empty():
		push_warning("SaveManager: no active save slot")
		return
	var data := _build_save_data()
	var file = FileAccess.open(_save_path(current_save_id), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	_sync_manifest_entry()

func load_game(save_id: String = "") -> bool:
	var id = save_id if not save_id.is_empty() else current_save_id
	if id.is_empty():
		return false
	var path = _save_path(id)
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return false
	file.close()
	current_save_id = id
	_apply_save_data(json.data)
	_touch_login_time()
	return true

func has_save() -> bool:
	return not _load_manifest().get("saves", []).is_empty()

func _build_save_data() -> Dictionary:
	return {
		"player": {
			"level": PlayerData.level,
			"exp": PlayerData.exp,
			"gold": PlayerData.gold,
			"enhance_stone": PlayerData.enhance_stone,
			"blessed_enhance_stone": PlayerData.blessed_enhance_stone,
			"jewelry_enhance_stone": PlayerData.jewelry_enhance_stone,
			"blessed_jewelry_enhance_stone": PlayerData.blessed_jewelry_enhance_stone,
			"health_potion": PlayerData.health_potion,
			"base_stats": PlayerData.base_stats.duplicate(),
			"primary_stats": PlayerData.primary_stats.duplicate(),
			"class": Game.player_class,
			"altar_buffs": PlayerData.altar_buffs.duplicate(true),
			"battle_roar_remaining": PlayerData.battle_roar_remaining,
			"battle_roar_atk_spd_percent": PlayerData.battle_roar_atk_spd_percent,
		},
		"equipment": PlayerData.equipped.duplicate(),
		"inventory": PlayerData.inventory.duplicate(true),
		"dungeon": Game.dungeon_progress.duplicate(),
		"world": {
			"current_dungeon_id": Game.current_dungeon_id,
			"auto_battle": Game.auto_battle,
		},
	}

func _apply_save_data(data: Dictionary) -> void:
	var p = data.get("player", {})
	PlayerData.level = p.get("level", 1)
	PlayerData.exp = p.get("exp", 0)
	PlayerData.gold = p.get("gold", 0)
	PlayerData.enhance_stone = p.get("enhance_stone", 0)
	PlayerData.blessed_enhance_stone = p.get("blessed_enhance_stone", 0)
	PlayerData.jewelry_enhance_stone = p.get("jewelry_enhance_stone", 0)
	PlayerData.blessed_jewelry_enhance_stone = p.get("blessed_jewelry_enhance_stone", 0)
	PlayerData.health_potion = p.get("health_potion", 0)
	PlayerData.altar_buffs = p.get("altar_buffs", []).duplicate(true)
	PlayerData.battle_roar_remaining = float(p.get("battle_roar_remaining", 0.0))
	PlayerData.battle_roar_atk_spd_percent = float(
		p.get("battle_roar_atk_spd_percent", p.get("battle_roar_atk_percent", 0.0))
	)
	Game.player_class = p.get("class", "")
	var saved_stats = p.get("base_stats", {})
	for key in saved_stats:
		PlayerData.base_stats[key] = saved_stats[key]
	var saved_primary = p.get("primary_stats", {})
	if saved_primary.has("STR"):
		for key in saved_primary:
			PlayerData.primary_stats[key] = int(saved_primary[key])
		PlayerData._sync_base_stats()
	else:
		PlayerData._migrate_from_base_stats()
	PlayerData.equipped = data.get("equipment", {})
	PlayerData.inventory = data.get("inventory", [])
	_fix_duplicate_uids(PlayerData.inventory)
	Equipment.sync_uid_counter(PlayerData.inventory)
	var dungeon_data = data.get("dungeon", {})
	Game.migrate_dungeon_progress(dungeon_data)
	Game.dungeon_progress = dungeon_data
	var world = data.get("world", {})
	Game.current_dungeon_id = world.get("current_dungeon_id", "bone_crypt")
	Game.auto_battle = world.get("auto_battle", false)
	_migrate_equipped_slots()
	_purge_obsolete_equipment()
	_migrate_equipment_data(PlayerData.inventory)

func _sync_manifest_entry() -> void:
	if current_save_id.is_empty():
		return
	var manifest = _load_manifest()
	var saves: Array = manifest.get("saves", [])
	var entry := {
		"id": current_save_id,
		"character_id": _manifest_character_id_for_current(),
		"player_class": Game.player_class,
		"level": PlayerData.level,
		"last_login_at": int(Time.get_unix_time_from_system()),
		"current_dungeon_id": Game.current_dungeon_id,
	}
	var found := false
	for i in saves.size():
		if saves[i].get("id", "") == current_save_id:
			saves[i] = entry
			found = true
			break
	if not found:
		saves.append(entry)
	manifest["saves"] = saves
	_write_manifest(manifest)

func _manifest_character_id_for_current() -> String:
	var nm = _network_manager()
	if nm and nm.logged_in:
		return nm.get_character_id()
	for s in _load_manifest().get("saves", []):
		if s.get("id", "") == current_save_id:
			return ApiIds.from_value(s.get("character_id", ""))
	return ""

func _touch_login_time() -> void:
	if current_save_id.is_empty():
		return
	var manifest = _load_manifest()
	var saves: Array = manifest.get("saves", [])
	var now = int(Time.get_unix_time_from_system())
	for i in saves.size():
		if saves[i].get("id", "") == current_save_id:
			saves[i]["last_login_at"] = now
			manifest["saves"] = saves
			_write_manifest(manifest)
			return

func _migrate_equipped_slots() -> void:
	if not PlayerData.equipped.has("legs"):
		PlayerData.equipped["legs"] = ""
	if PlayerData.equipped.has("ring"):
		var old_ring: String = PlayerData.equipped["ring"]
		PlayerData.equipped.erase("ring")
		if not PlayerData.equipped.has("ring_left"):
			PlayerData.equipped["ring_left"] = old_ring
	if not PlayerData.equipped.has("ring_left"):
		PlayerData.equipped["ring_left"] = ""
	if not PlayerData.equipped.has("ring_right"):
		PlayerData.equipped["ring_right"] = ""

func _purge_obsolete_equipment() -> void:
	PlayerData.inventory = PlayerData.inventory.filter(func(eq):
		if Equipment.is_jewelry(eq):
			var line_id = eq.get("jewelry_line", "")
			if eq.get("slot", "") == "necklace":
				return not line_id.is_empty() and not DataManager.get_necklace_line(line_id).is_empty()
			return not line_id.is_empty() and not DataManager.get_jewelry_line(line_id).is_empty()
		var base_id: String = eq.get("base_id", "")
		return not base_id.is_empty() and not DataManager.get_equipment_base(base_id).is_empty()
	)
	for slot in PlayerData.equipped:
		var uid: String = PlayerData.equipped[slot]
		if not uid.is_empty() and PlayerData.get_equipment_by_uid(uid).is_empty():
			PlayerData.equipped[slot] = ""

func _fix_duplicate_uids(inventory: Array) -> void:
	var seen_uids := {}
	for eq in inventory:
		var uid: String = eq.get("uid", "")
		if uid.is_empty():
			continue
		if seen_uids.has(uid):
			eq["uid"] = Equipment.generate_uid()
		else:
			seen_uids[uid] = true
		if eq.has("enhance_level"):
			eq["enhance_level"] = int(eq["enhance_level"])

func _migrate_equipment_data(inventory: Array) -> void:
	for eq in inventory:
		if Equipment.is_jewelry(eq):
			var line_id = eq.get("jewelry_line", "")
			var level = int(eq.get("enhance_level", 0))
			if not line_id.is_empty():
				Equipment.apply_jewelry_level(eq, clampi(level, 0, Equipment.MAX_JEWELRY_ENHANCE_LEVEL))
			continue
		var base_id = eq.get("base_id", "")
		var base_data = DataManager.get_equipment_base(base_id)
		if base_data.is_empty():
			continue
		var needs_migration = false
		for field in ["name", "type", "class_req", "dual_wield", "effects"]:
			if not eq.has(field) or (field == "name" and eq.get("name", "").is_empty()):
				needs_migration = true
				break
		if eq.has("grade"):
			eq.erase("grade")
		if eq.has("affixes"):
			eq.erase("affixes")
		if eq.has("req_level"):
			eq.erase("req_level")
			needs_migration = true
		if not eq.has("safe_enhance_until"):
			eq["safe_enhance_until"] = int(base_data.get("safe_enhance_until",
				DataManager.get_enhance_rules().get("default_safe_until", 3)))
			needs_migration = true
		if not eq.has("is_blessed"):
			eq["is_blessed"] = false
			needs_migration = true
		if needs_migration:
			if not eq.has("name") or eq.get("name", "").is_empty():
				eq["name"] = base_data.get("name", "未知装备")
			if not eq.has("type"):
				eq["type"] = base_data.get("type", "")
			if not eq.has("class_req"):
				eq["class_req"] = base_data.get("class_req", "")
			if not eq.has("dual_wield"):
				eq["dual_wield"] = base_data.get("dual_wield", false)
			if not eq.has("effects"):
				eq["effects"] = base_data.get("effects", {}).duplicate(true)
