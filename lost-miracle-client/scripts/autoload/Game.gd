extends Node

## 全局状态管理 — 场景切换、游戏状态

# 玩家职业（warrior/ranger/assassin/elven，空字符串表示未选择）
var player_class: String = ""
# 自动战斗开关（跨战斗持久化）
var auto_battle: bool = false

# 当前选择的地牢
var current_dungeon_id: String = "bone_crypt"

const BOSS_RESPAWN_SEC := 300
const ELITE_RESPAWN_SEC := 120

# 地牢进度
var dungeon_progress := {
	"normal_kill_count": 0,
	"elite_kill_count": 0,
	"boss_kill_count": 0,
	"boss_defeated": false,
	"boss_respawn_at": 0.0,
	"elite_respawn_at": 0.0,
}

func reset_dungeon() -> void:
	dungeon_progress = {
		"normal_kill_count": 0,
		"elite_kill_count": 0,
		"boss_kill_count": 0,
		"boss_defeated": false,
		"boss_respawn_at": 0.0,
		"elite_respawn_at": 0.0,
	}

func is_boss_available() -> bool:
	var respawn_at = float(dungeon_progress.get("boss_respawn_at", 0))
	if respawn_at <= 0:
		return true
	return Time.get_unix_time_from_system() >= respawn_at

func is_elite_available() -> bool:
	var respawn_at = float(dungeon_progress.get("elite_respawn_at", 0))
	if respawn_at <= 0:
		return true
	return Time.get_unix_time_from_system() >= respawn_at

func get_boss_cooldown_remaining() -> int:
	if is_boss_available():
		return 0
	return maxi(0, int(ceil(float(dungeon_progress.get("boss_respawn_at", 0)) - Time.get_unix_time_from_system())))

func get_elite_cooldown_remaining() -> int:
	if is_elite_available():
		return 0
	return maxi(0, int(ceil(float(dungeon_progress.get("elite_respawn_at", 0)) - Time.get_unix_time_from_system())))

func can_challenge_boss() -> bool:
	return is_boss_available()

func mark_boss_killed() -> void:
	dungeon_progress["boss_kill_count"] = int(dungeon_progress.get("boss_kill_count", 0)) + 1
	dungeon_progress["boss_defeated"] = true
	dungeon_progress["boss_respawn_at"] = Time.get_unix_time_from_system() + BOSS_RESPAWN_SEC

func mark_elite_killed() -> void:
	dungeon_progress["elite_respawn_at"] = Time.get_unix_time_from_system() + ELITE_RESPAWN_SEC

func format_cooldown(seconds: int) -> String:
	var mins = seconds / 60
	var secs = seconds % 60
	return "%d:%02d" % [mins, secs]

func migrate_dungeon_progress(data: Dictionary) -> void:
	for key in ["normal_kill_count", "elite_kill_count", "boss_kill_count"]:
		if not data.has(key):
			data[key] = 0
	if not data.has("boss_defeated"):
		data["boss_defeated"] = false
	if not data.has("boss_respawn_at"):
		data["boss_respawn_at"] = 0.0
	if not data.has("elite_respawn_at"):
		data["elite_respawn_at"] = 0.0

## 获取当前玩家职业
func get_player_class() -> String:
	return player_class

## 设置玩家职业
func set_player_class(new_class: String) -> void:
	player_class = new_class
