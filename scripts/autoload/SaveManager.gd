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
			"base_stats": PlayerData.base_stats.duplicate(),
			"primary_stats": PlayerData.primary_stats.duplicate(),
			"unallocated_points": PlayerData.unallocated_points,
			"class": Game.player_class,
		},
		"equipment": PlayerData.equipped.duplicate(),
		"inventory": PlayerData.inventory.duplicate(true),
		"dungeon": Game.dungeon_progress.duplicate(),
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
	var saved_stats = p.get("base_stats", {})
	for key in saved_stats:
		PlayerData.base_stats[key] = saved_stats[key]
	# 恢复基础属性（兼容旧存档）
	var saved_primary = p.get("primary_stats", {})
	if saved_primary.has("STR"):
		# 新存档：直接恢复
		for key in saved_primary:
			PlayerData.primary_stats[key] = int(saved_primary[key])
		PlayerData.unallocated_points = int(p.get("unallocated_points", 0))
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
	Game.dungeon_progress = data.get("dungeon", {})
	# 恢复玩家职业
	Game.player_class = p.get("class", "")
	# 迁移旧装备数据（添加新字段）
	_migrate_equipment_data(PlayerData.inventory)
	return true

func _fix_duplicate_uids(inventory: Array) -> void:
	var seen_uids := {}
	for eq in inventory:
		var uid: String = eq.get("uid", "")
		if uid.is_empty():
			continue
		if seen_uids.has(uid):
			# 发现重复 uid，生成新的
			var old_uid = uid
			var new_uid = Equipment.generate_uid()
			eq["uid"] = new_uid
			print("[Load] Fixed duplicate uid: %s -> %s (%s)" % [old_uid, new_uid, eq.get("name", "?")])
		else:
			seen_uids[uid] = true
		# 修复 JSON 解析导致的类型问题
		if eq.has("enhance_level"):
			eq["enhance_level"] = int(eq["enhance_level"])

## 迁移旧装备数据，添加新字段
func _migrate_equipment_data(inventory: Array) -> void:
	var migrated_count = 0
	for eq in inventory:
		# 如果缺少新字段，从 equipment_base 补充
		if not eq.has("type") or not eq.has("class_req") or not eq.has("effects"):
			var base_id = eq.get("base_id", "")
			var base_data = DataManager.get_equipment_base(base_id)
			if not base_data.is_empty():
				if not eq.has("type"):
					eq["type"] = base_data.get("type", "")
				if not eq.has("class_req"):
					eq["class_req"] = base_data.get("class_req", "")
				if not eq.has("dual_wield"):
					eq["dual_wield"] = base_data.get("dual_wield", false)
				if not eq.has("effects"):
					eq["effects"] = base_data.get("effects", {}).duplicate(true)
				migrated_count += 1
	if migrated_count > 0:
		print("[Load] Migrated %d equipment items to new data format" % migrated_count)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
