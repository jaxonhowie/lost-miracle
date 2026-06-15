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

func create_http_request() -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = int(ApiConfig.TIMEOUT)
	add_child(http)
	return http

func _ready() -> void:
	_try_restore_token()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		exit_application()

func exit_application() -> void:
	if logged_in and has_character():
		SaveManager.save_game()
	logout()
	get_tree().quit()

func _try_restore_token() -> void:
	if not FileAccess.file_exists(TOKEN_PATH):
		return
	var file = FileAccess.open(TOKEN_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data: Dictionary = json.data
	token = str(data.get("token", ""))
	user_id = ApiIds.from_value(data.get("user_id", ""))
	username = str(data.get("username", ""))
	if not token.is_empty():
		logged_in = true
		_character_id = ApiIds.from_value(data.get("character_id", ""))
		_save_version = int(data.get("save_version", 0))
		loginStateChanged.emit()

func _persist_token() -> void:
	var file = FileAccess.open(TOKEN_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"token": token,
			"user_id": user_id,
			"username": username,
			"character_id": _character_id,
			"save_version": _save_version,
		}, "\t"))
		file.close()

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
	_persist_token()
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

func list_characters() -> Dictionary:
	return await _api.make_request("GET", "/characters", {}, token)

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

func has_character() -> bool:
	return not _character_id.is_empty()

func get_character_id() -> String:
	return _character_id

func set_character_id(id: String) -> void:
	_character_id = ApiIds.from_value(id)
	_persist_token()

func get_save_version() -> int:
	return _save_version

func set_save_version(v: int) -> void:
	_save_version = v
	_persist_token()

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
