extends Node

## 全局状态管理 — 场景切换、游戏状态

var player_class: String = ""
var auto_battle: bool = false
var current_dungeon_id: String = "bone_crypt"

var dungeon_progress := {
	"normal_kill_count": 0,
	"elite_kill_count": 0,
	"boss_kill_count": 0,
}

func reset_dungeon() -> void:
	dungeon_progress = {
		"normal_kill_count": 0,
		"elite_kill_count": 0,
		"boss_kill_count": 0,
	}

func is_boss_available() -> bool:
	return SpawnService.is_boss_available()

func is_elite_available() -> bool:
	return SpawnService.is_elite_available()

func get_boss_cooldown_remaining() -> int:
	return SpawnService.get_boss_cooldown_remaining()

func get_elite_cooldown_remaining() -> int:
	return SpawnService.get_elite_cooldown_remaining()

func can_challenge_boss() -> bool:
	return is_boss_available()

func mark_boss_killed() -> void:
	dungeon_progress["boss_kill_count"] = int(dungeon_progress.get("boss_kill_count", 0)) + 1

func format_cooldown(seconds: int) -> String:
	var mins = seconds / 60
	var secs = seconds % 60
	return "%d:%02d" % [mins, secs]

func migrate_dungeon_progress(data: Dictionary) -> void:
	for key in ["normal_kill_count", "elite_kill_count", "boss_kill_count"]:
		if not data.has(key):
			data[key] = 0
	data.erase("boss_defeated")
	data.erase("boss_respawn_at")
	data.erase("elite_respawn_at")

func get_player_class() -> String:
	return player_class

func set_player_class(new_class: String) -> void:
	player_class = new_class
