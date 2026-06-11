extends Node

## 存档管理 — user://save.json

const SAVE_PATH = "user://save.json"

func save_game() -> void:
	var data := {
		"player": {
			"level": PlayerData.level,
			"exp": PlayerData.exp,
			"gold": PlayerData.gold,
			"enhance_stone": PlayerData.enhance_stone,
			"blessed_enhance_stone": PlayerData.blessed_enhance_stone,
			"health_potion": PlayerData.health_potion,
			"base_stats": PlayerData.base_stats.duplicate(),
			"primary_stats": PlayerData.primary_stats.duplicate(),
			"class": Game.player_class,
			"altar_buffs": PlayerData.altar_buffs.duplicate(true),
		},
		"equipment": PlayerData.equipped.duplicate(),
		"inventory": PlayerData.inventory.duplicate(true),
		"dungeon": Game.dungeon_progress.duplicate(),
		"world": {
			"current_dungeon_id": Game.current_dungeon_id,
			"cleared_dungeons": Game.cleared_dungeons.duplicate(),
		},
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	file.close()
	var data = json.data
	# 恢复玩家数据
	var p = data.get("player", {})
	PlayerData.level = p.get("level", 1)
	PlayerData.exp = p.get("exp", 0)
	PlayerData.gold = p.get("gold", 0)
	PlayerData.enhance_stone = p.get("enhance_stone", 0)
	PlayerData.blessed_enhance_stone = p.get("blessed_enhance_stone", 0)
	PlayerData.health_potion = p.get("health_potion", 0)
	PlayerData.altar_buffs = p.get("altar_buffs", []).duplicate(true)
	# 恢复玩家职业（属性分配依赖职业）
	Game.player_class = p.get("class", "")
	var saved_stats = p.get("base_stats", {})
	for key in saved_stats:
		PlayerData.base_stats[key] = saved_stats[key]
	# 恢复基础属性（兼容旧存档）
	var saved_primary = p.get("primary_stats", {})
	if saved_primary.has("STR"):
		# 新存档：直接恢复
		for key in saved_primary:
			PlayerData.primary_stats[key] = int(saved_primary[key])
		PlayerData._sync_base_stats()
	else:
		# 旧存档：从 base_stats 推算基础属性
		PlayerData._migrate_from_base_stats()
	# 恢复装备
	PlayerData.equipped = data.get("equipment", {})
	# 恢复背包
	PlayerData.inventory = data.get("inventory", [])
	# 修复重复 uid
	_fix_duplicate_uids(PlayerData.inventory)
	Equipment.sync_uid_counter(PlayerData.inventory)
	# 恢复地牢进度
	var dungeon_data = data.get("dungeon", {})
	Game.migrate_dungeon_progress(dungeon_data)
	Game.dungeon_progress = dungeon_data
	var world = data.get("world", {})
	Game.current_dungeon_id = world.get("current_dungeon_id", "bone_crypt")
	Game.cleared_dungeons = world.get("cleared_dungeons", []).duplicate()
	_migrate_equipped_slots()
	_purge_obsolete_equipment()
	_migrate_equipment_data(PlayerData.inventory)
	return true

func _migrate_equipped_slots() -> void:
	if not PlayerData.equipped.has("legs"):
		PlayerData.equipped["legs"] = ""

func _purge_obsolete_equipment() -> void:
	PlayerData.inventory = PlayerData.inventory.filter(func(eq):
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
			# 发现重复 uid，生成新的
			var new_uid = Equipment.generate_uid()
			eq["uid"] = new_uid
		else:
			seen_uids[uid] = true
		# 修复 JSON 解析导致的类型问题
		if eq.has("enhance_level"):
			eq["enhance_level"] = int(eq["enhance_level"])

## 迁移旧装备数据，添加新字段
func _migrate_equipment_data(inventory: Array) -> void:
	var migrated_count = 0
	for eq in inventory:
		var base_id = eq.get("base_id", "")
		var base_data = DataManager.get_equipment_base(base_id)
		if base_data.is_empty():
			continue
		var needs_migration = false
		# 补充缺失的字段
		for field in ["name", "type", "class_req", "dual_wield", "effects"]:
			if not eq.has(field) or (field == "name" and eq.get("name", "").is_empty()):
				needs_migration = true
				break
		if not eq.has("grade"):
			eq["grade"] = base_data.get("grade", "normal")
			needs_migration = true
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
		if not eq.has("affixes"):
			eq["affixes"] = []
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
			migrated_count += 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
