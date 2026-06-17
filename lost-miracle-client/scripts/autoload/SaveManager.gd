extends Node

## 游戏状态序列化 — 纯内存，持久化由 CloudSaveService 负责

const DISPLAY_SLOT_COUNT := 3
const SLOT_WIDTH := 520
const SLOT_HEIGHT := 96

var session_active: bool = false


func get_cloud_display_slots(characters: Array, max_slots: int = DISPLAY_SLOT_COUNT) -> Array:
	var result := []
	for ch in characters:
		if result.size() >= max_slots:
			break
		var char_id := ApiIds.from_value(ch.get("id", 0))
		result.append({
			"empty": false,
			"meta": {
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


func export_save_data() -> Dictionary:
	return _build_save_data()


func import_save_data(data: Dictionary) -> void:
	_apply_save_data(data)
	session_active = true


func reset_for_new_game() -> void:
	PlayerData.reset_for_new_game()
	Game.player_class = "warrior"
	Game.auto_battle = false
	Game.current_dungeon_id = "bone_crypt"
	Game.reset_dungeon()
	session_active = true


func clear_session() -> void:
	session_active = false


func save_game() -> void:
	if not session_active and NetworkManager.has_character():
		session_active = true


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
	var session_roar_remaining := PlayerData.battle_roar_remaining
	var session_roar_percent := PlayerData.battle_roar_atk_spd_percent
	PlayerData.battle_roar_remaining = float(p.get("battle_roar_remaining", 0.0))
	PlayerData.battle_roar_atk_spd_percent = float(
		p.get("battle_roar_atk_spd_percent", p.get("battle_roar_atk_percent", 0.0))
	)
	if session_roar_remaining > 0.0:
		PlayerData.battle_roar_remaining = session_roar_remaining
		PlayerData.battle_roar_atk_spd_percent = session_roar_percent
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
	var session_auto_battle := Game.auto_battle
	Game.auto_battle = world.get("auto_battle", false)
	if session_auto_battle:
		Game.auto_battle = true
	_migrate_equipped_slots()
	_purge_obsolete_equipment()
	_migrate_equipment_data(PlayerData.inventory)


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
