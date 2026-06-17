extends Node

## 全局登录态与云存档同步

var token: String = ""
var user_id: String = ""
var username: String = ""
var logged_in: bool = false

var _save_version: int = 0
var _character_id: String = ""
var _api: ApiClient = ApiClient.new()

const TOKEN_PATH := "user://auth_token.json"

signal loginStateChanged
## 鉴权失效（token 过期/无效，服务端返回 403）时发出，订阅者可提示重新登录。
signal auth_invalid

func create_http_request() -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = int(ApiConfig.TIMEOUT)
	add_child(http)
	return http

func _ready() -> void:
	_clear_token()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		exit_application()

func exit_application() -> void:
	if logged_in and has_character() and SaveManager.session_active:
		await cloud_sync_save_await()
	await end_session()
	get_tree().quit()

func end_session() -> void:
	await _revoke_server_token()
	logout()

func _revoke_server_token() -> void:
	if token.is_empty():
		return
	await _api.make_request("POST", "/auth/logout", {}, token)

func _clear_token() -> void:
	if FileAccess.file_exists(TOKEN_PATH):
		DirAccess.open("user://").remove("auth_token.json")

func login(user: String, pwd: String) -> Dictionary:
	var result = await _api.make_request("POST", "/auth/login", {
		"username": user,
		"password": pwd,
	})
	if result.get("ok", false):
		_apply_auth(result["data"], user)
	return result

func register(user: String, pwd: String) -> Dictionary:
	var result = await _api.make_request("POST", "/auth/register", {
		"username": user,
		"password": pwd,
	})
	if result.get("ok", false):
		_apply_auth(result["data"], user)
	return result

func _apply_auth(data: Dictionary, user: String) -> void:
	token = str(data.get("accessToken", ""))
	user_id = ApiIds.from_value(data.get("userId", data.get("user_id", 0)))
	username = user
	logged_in = true
	_character_id = ""
	_save_version = 0
	loginStateChanged.emit()

func logout() -> void:
	token = ""
	user_id = ""
	username = ""
	logged_in = false
	_save_version = 0
	_character_id = ""
	_clear_token()
	loginStateChanged.emit()


## 请求结果出现鉴权失效（HTTP 403）时调用：清理失效登录态并广播。
## 与 logout 的区别：保留 user_id/username 以便回登录页预填，仅清 token。
func handle_auth_failure() -> void:
	if token.is_empty() and not logged_in:
		return
	token = ""
	logged_in = false
	_clear_token()
	auth_invalid.emit()
	loginStateChanged.emit()

func api_request(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	var result = await _api.make_request(method, path, body, token)
	if _is_auth_failure_result(result):
		handle_auth_failure()
	return result

func _is_auth_failure_result(result: Dictionary) -> bool:
	if int(result.get("code", 0)) == ApiConfig.CLIENT_AUTH_EXPIRED_CODE:
		return true
	var status := int(result.get("http_status", 0))
	return status == ApiConfig.HTTP_UNAUTHORIZED

func list_characters() -> Dictionary:
	return await api_request("GET", "/characters")

func create_character(char_name: String = "") -> Dictionary:
	var body := {}
	if not char_name.is_empty():
		body["name"] = char_name
	return await _api.make_request("POST", "/characters", body, token)

func delete_character(char_id: String) -> Dictionary:
	var cid := ApiIds.from_value(char_id)
	if cid.is_empty():
		return {"ok": false, "code": -1, "message": "无效角色", "data": {}}
	return await _api.make_request("DELETE", "/characters/%s" % cid, {}, token)

func rename_character(char_id: String, char_name: String) -> Dictionary:
	var cid := ApiIds.from_value(char_id)
	if cid.is_empty():
		return {"ok": false, "code": -1, "message": "无效角色", "data": {}}
	return await _api.make_request("PATCH", "/characters/%s" % cid, {"name": char_name}, token)

func download_save(char_id: String) -> Dictionary:
	var cid := ApiIds.from_value(char_id)
	return await _api.make_request("GET", "/characters/%s/save" % cid, {}, token)

func upload_save(char_id: String, save_data: Dictionary, save_version: int, force: bool = false) -> Dictionary:
	var cid := ApiIds.from_value(char_id)
	var body := {
		"saveVersion": save_version,
		"clientUpdatedAt": int(Time.get_unix_time_from_system()),
		"save": save_data,
	}
	if force:
		body["force"] = true
	return await _api.make_request("PUT", "/characters/%s/save" % cid, body, token)

func get_spawn_state(dungeon_id: String) -> Dictionary:
	if not has_character():
		return {"ok": false, "code": -1, "message": "未选择角色", "data": {}}
	return await _api.make_request(
		"GET",
		"/characters/%s/dungeons/%s/spawns" % [_character_id, dungeon_id],
		{},
		token
	)

func spawn_encounter(dungeon_id: String, spawn_type: String) -> Dictionary:
	if not has_character():
		return {"ok": false, "code": -1, "message": "未选择角色", "data": {}}
	return await _api.make_request(
		"POST",
		"/characters/%s/dungeons/%s/spawns/encounter" % [_character_id, dungeon_id],
		{"type": spawn_type},
		token
	)

func spawn_defeat(dungeon_id: String, slot_id: String) -> Dictionary:
	if not has_character():
		return {"ok": false, "code": -1, "message": "未选择角色", "data": {}}
	var sid := ApiIds.from_value(slot_id)
	return await _api.make_request(
		"POST",
		"/characters/%s/dungeons/%s/spawns/%s/defeat" % [_character_id, dungeon_id, sid],
		{},
		token
	)

func spawn_settle(dungeon_id: String, slot_id: String, monster_id: String) -> Dictionary:
	if not has_character():
		return {"ok": false, "code": -1, "message": "未选择角色", "data": {}}
	var sid := ApiIds.from_value(slot_id)
	return await _api.make_request(
		"POST",
		"/characters/%s/dungeons/%s/spawns/%s/settle" % [_character_id, dungeon_id, sid],
		{
			"saveVersion": _save_version,
			"monsterId": monster_id,
		},
		token
	)

func spawn_release(dungeon_id: String, slot_id: String) -> Dictionary:
	if not has_character():
		return {"ok": false, "code": -1, "message": "未选择角色", "data": {}}
	var sid := ApiIds.from_value(slot_id)
	return await _api.make_request(
		"POST",
		"/characters/%s/dungeons/%s/spawns/%s/release" % [_character_id, dungeon_id, sid],
		{},
		token
	)

func has_character() -> bool:
	return not _character_id.is_empty()

func get_character_id() -> String:
	return _character_id

func set_character_id(id: String) -> void:
	_character_id = ApiIds.from_value(id)

func get_save_version() -> int:
	return _save_version

func set_save_version(v: int) -> void:
	_save_version = v

func cloud_sync_save() -> void:
	var cloud: Node = _cloud_save_service()
	if cloud:
		cloud.request_background_sync()

func cloud_sync_save_await() -> Dictionary:
	var cloud: Node = _cloud_save_service()
	if cloud:
		return await cloud.sync_current()
	return {"ok": false, "message": "CloudSaveService unavailable", "data": {}}

func enhance_roll(equipment_uid: String, use_blessed: bool) -> Dictionary:
	if not has_character():
		return {"ok": false, "code": -1, "message": "未选择角色", "data": {}}
	return await _api.make_request(
		"POST",
		"/characters/%s/enhance/roll" % _character_id,
		{
			"equipmentUid": equipment_uid,
			"useBlessedStone": use_blessed,
			"saveVersion": _save_version,
		},
		token
	)

func apply_server_save(save_data: Dictionary, new_save_version: int) -> void:
	var cloud: Node = _cloud_save_service()
	if cloud:
		cloud.apply_server_save(save_data, new_save_version)

func _cloud_save_service() -> Node:
	return get_node_or_null("/root/CloudSaveService")

func get_leaderboard(character_id: String = "") -> Dictionary:
	var query := "?page=1&page_size=50"
	var cid := ApiIds.from_value(character_id)
	if not cid.is_empty():
		query += "&characterId=%s" % cid
	return await _api.make_request("GET", "/leaderboards/power" + query, {}, token)

func list_mail(char_id: String) -> Dictionary:
	var cid := ApiIds.from_value(char_id)
	return await _api.make_request("GET", "/characters/%s/mail" % cid, {}, token)

func claim_mail(char_id: String, mail_id: int) -> Dictionary:
	var cid := ApiIds.from_value(char_id)
	return await _api.make_request(
		"POST",
		"/characters/%s/mail/%d/claim" % [cid, mail_id],
		{"saveVersion": _save_version},
		token
	)

func list_achievements(char_id: String) -> Dictionary:
	var cid := ApiIds.from_value(char_id)
	return await _api.make_request("GET", "/achievements?characterId=%s" % cid, {}, token)

func claim_achievement(char_id: String, achievement_id: String) -> Dictionary:
	var cid := ApiIds.from_value(char_id)
	return await _api.make_request(
		"POST",
		"/achievements/%s/claim?characterId=%s" % [achievement_id, cid],
		{"saveVersion": _save_version},
		token
	)
