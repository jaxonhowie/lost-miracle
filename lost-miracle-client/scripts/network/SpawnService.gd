extends Node

## 服务端全局刷怪槽状态（按地图共享）

var _state: Dictionary = {}


func clear_cache() -> void:
	_state = {}


func refresh(dungeon_id: String) -> Dictionary:
	var result := await NetworkManager.get_spawn_state(dungeon_id)
	if result.get("ok", false):
		_state = result.get("data", {})
	return result


func encounter(spawn_type: String, dungeon_id: String) -> Dictionary:
	return await NetworkManager.spawn_encounter(dungeon_id, spawn_type)


func report_defeat(dungeon_id: String, slot_id: String) -> Dictionary:
	var result := await NetworkManager.spawn_defeat(dungeon_id, slot_id)
	if result.get("ok", false):
		await refresh(dungeon_id)
	return result


func report_release(dungeon_id: String, slot_id: String) -> Dictionary:
	var result := await NetworkManager.spawn_release(dungeon_id, slot_id)
	if result.get("ok", false):
		await refresh(dungeon_id)
	return result


func is_elite_available() -> bool:
	return bool(_state.get("elite", {}).get("available", false))


func is_boss_available() -> bool:
	return bool(_state.get("boss", {}).get("available", false))


func get_elite_cooldown_remaining() -> int:
	return int(_state.get("elite", {}).get("cooldownSec", 0))


func get_boss_cooldown_remaining() -> int:
	return int(_state.get("boss", {}).get("cooldownSec", 0))
