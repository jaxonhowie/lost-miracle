extends Node

## 全局状态管理 — 场景切换、游戏状态

enum GameState { MAIN_MENU, DUNGEON, BATTLE, INVENTORY, ENHANCE }

var current_state: GameState = GameState.MAIN_MENU
var current_floor: int = 1

# 玩家职业（warrior/ranger/mage，空字符串表示未选择）
var player_class: String = ""

# 地牢进度
var dungeon_progress := {
	"normal_kill_count": 0,
	"elite_kill_count": 0,
	"boss_defeated": false,
}

signal state_changed(new_state: GameState)
signal scene_change_requested(scene_path: String)

func change_scene(scene_path: String) -> void:
	scene_change_requested.emit(scene_path)

func set_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func reset_dungeon() -> void:
	dungeon_progress = {
		"normal_kill_count": 0,
		"elite_kill_count": 0,
		"boss_defeated": false,
	}

func can_challenge_boss() -> bool:
	return dungeon_progress["normal_kill_count"] >= 15 \
		and dungeon_progress["elite_kill_count"] >= 3 \
		and PlayerData.level >= 5

## 获取当前玩家职业
func get_player_class() -> String:
	return player_class

## 设置玩家职业
func set_player_class(new_class: String) -> void:
	player_class = new_class
	print("[Game] Player class set to: %s" % new_class)
