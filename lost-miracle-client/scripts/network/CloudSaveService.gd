extends Node

## 云存档同步：上传/下载、冲突处理、失败重试队列、状态广播

const CONFLICT_CODE := 40901
const RATE_LIMIT_CODE := 42900

enum SyncStatus {
	OFFLINE,
	IDLE,
	SYNCING,
	OK,
	FAILED,
	CONFLICT,
	QUEUED,
}

signal sync_completed(ok: bool, message: String)
signal sync_status_changed(status: int, message: String)

var _current_status: int = SyncStatus.IDLE
var _current_message: String = ""
var _sync_in_flight: bool = false
var _background_running: bool = false
var _retry_timer: Timer
var _retry_delay: float = ApiConfig.SYNC_RETRY_INIT_SEC
var _sync_queue: Array = []


func _ready() -> void:
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(_on_retry_timer)
	add_child(_retry_timer)
	NetworkManager.loginStateChanged.connect(_on_login_state_changed)
	NetworkManager.auth_invalid.connect(_on_auth_invalid)
	ConnectivityMonitor.connectivity_changed.connect(_on_connectivity_changed)
	ConnectivityMonitor.online_restored.connect(_on_online_restored)
	_refresh_status()
	call_deferred("try_resume_sync")


func _on_login_state_changed() -> void:
	_refresh_status()
	if NetworkManager.logged_in:
		call_deferred("try_resume_sync")
	else:
		_stop_retry_timer()
		_sync_queue.clear()


func _on_auth_invalid() -> void:
	_stop_retry_timer()
	_set_status(SyncStatus.OFFLINE, "登录已失效，请重新登录")


func _on_connectivity_changed(_online: bool) -> void:
	_refresh_status()


func _on_online_restored() -> void:
	if can_sync() and (has_pending_queue() or _current_status == SyncStatus.QUEUED):
		request_background_sync()


func get_status() -> int:
	return _current_status


func get_status_message() -> String:
	return _current_message


func get_status_text() -> String:
	match _current_status:
		SyncStatus.OFFLINE:
			return "未连接"
		SyncStatus.SYNCING:
			return "同步中..."
		SyncStatus.OK:
			return "已同步"
		SyncStatus.FAILED:
			return "同步失败"
		SyncStatus.CONFLICT:
			return "存档冲突"
		SyncStatus.QUEUED:
			return "待重试同步"
		_:
			return "就绪"


func can_sync() -> bool:
	return (
		NetworkManager.logged_in
		and NetworkManager.has_character()
		and SaveManager.session_active
		and ConnectivityMonitor.is_online()
	)


func has_pending_queue() -> bool:
	return not _sync_queue.is_empty()


func clear_pending_sync(char_id: String) -> void:
	_clear_queue_entry(char_id)


func try_resume_sync() -> void:
	if not NetworkManager.logged_in or not NetworkManager.has_character():
		return
	if not has_pending_queue() and _current_status != SyncStatus.QUEUED:
		return
	if not ConnectivityMonitor.is_online():
		_refresh_status()
		_schedule_retry()
		return
	if not _background_running and not _sync_in_flight:
		request_background_sync()
	_schedule_retry()


func download_for_character(char_id: String) -> Dictionary:
	return await NetworkManager.download_save(char_id)


func upload_for_character(char_id: String, save_data: Dictionary, save_version: int, force: bool = false) -> Dictionary:
	return await NetworkManager.upload_save(char_id, save_data, save_version, force)


func apply_server_save(save_data: Dictionary, save_version: int) -> void:
	SaveManager.import_save_data(save_data)
	NetworkManager.set_save_version(save_version)
	_clear_queue_entry(NetworkManager.get_character_id())
	_stop_retry_timer()
	_set_status(SyncStatus.OK, "已同步")


func bind_cloud_character(char_meta: Dictionary, cloud_save: Dictionary, save_version: int) -> void:
	var char_id := ApiIds.from_value(char_meta.get("id", char_meta.get("character_id", "")))
	SaveManager.import_save_data(cloud_save)
	NetworkManager.set_character_id(char_id)
	NetworkManager.set_save_version(save_version)
	_clear_queue_entry(char_id)
	_stop_retry_timer()
	_set_status(SyncStatus.OK, "已同步")


func sync_current() -> Dictionary:
	if not NetworkManager.logged_in:
		return {"ok": false, "code": -1, "message": "未登录"}
	if not ConnectivityMonitor.is_online():
		return {"ok": false, "code": -1, "message": "无法连接服务器"}
	var char_id := NetworkManager.get_character_id()
	if char_id.is_empty() or not SaveManager.session_active:
		return {"ok": false, "code": -1, "message": "未选择角色"}
	var save_data := SaveManager.export_save_data()
	var result := await upload_for_character(char_id, save_data, NetworkManager.get_save_version())
	if result.get("ok", false):
		NetworkManager.set_save_version(int(result["data"].get("saveVersion", NetworkManager.get_save_version())))
		_clear_queue_entry(char_id)
		_reset_retry_delay()
		sync_completed.emit(true, "同步成功")
		return result
	if _is_auth_failure(result):
		NetworkManager.handle_auth_failure()
		sync_completed.emit(false, "登录已失效")
		return result
	if int(result.get("code", 0)) == CONFLICT_CODE:
		sync_completed.emit(false, "存档版本冲突")
		return result
	if int(result.get("code", 0)) == RATE_LIMIT_CODE:
		sync_completed.emit(false, "同步过于频繁")
		return result
	_enqueue_sync(char_id, save_data, NetworkManager.get_save_version())
	sync_completed.emit(false, str(result.get("message", "同步失败")))
	return result


func sync_to_cloud(parent: Node = null, interact_on_conflict: bool = true) -> Dictionary:
	if not NetworkManager.logged_in or not NetworkManager.has_character():
		return {"ok": false, "code": -1, "message": "未登录或未选择角色"}
	if not SaveManager.session_active:
		return {"ok": false, "code": -1, "message": "无存档会话"}
	if not ConnectivityMonitor.is_online():
		_set_status(SyncStatus.OFFLINE, "无法连接服务器")
		return {"ok": false, "code": -1, "message": "无法连接服务器"}

	while _sync_in_flight:
		await get_tree().process_frame

	_sync_in_flight = true
	_set_status(SyncStatus.SYNCING, "同步中...")
	var result := await sync_current()
	_sync_in_flight = false

	if result.get("ok", false):
		_set_status(SyncStatus.OK, "已同步")
		_stop_retry_timer()
		return result

	if int(result.get("code", 0)) == CONFLICT_CODE:
		var host := parent if parent != null and is_instance_valid(parent) else get_tree().root
		return await handle_conflict(host, result)

	if _is_auth_failure(result):
		_set_status(SyncStatus.OFFLINE, "登录已失效，请重新登录")
		return result

	if int(result.get("code", 0)) == RATE_LIMIT_CODE:
		_set_status(SyncStatus.QUEUED, "同步过于频繁，稍后重试")
		_schedule_retry()
		result["queued"] = true
		return result

	_set_status(SyncStatus.QUEUED, "同步失败，已加入重试队列")
	_schedule_retry()
	return result


func sync_after_local_save(parent: Node = null, interact_on_conflict: bool = true) -> Dictionary:
	return await sync_to_cloud(parent, interact_on_conflict)


func _reset_retry_delay() -> void:
	_retry_delay = ApiConfig.SYNC_RETRY_INIT_SEC


func sync_before_scene_exit(parent: Node) -> Dictionary:
	var result := await sync_to_cloud(parent, true)
	if result.get("relogin", false):
		return result
	if not result.get("ok", false) and not _is_auth_failure(result):
		_show_toast(parent, "存档同步失败，请检查网络后重试")
	return result


func request_background_sync() -> void:
	if _background_running or _sync_in_flight:
		return
	_background_running = true
	_run_background_sync()


## 游戏进行中非阻塞存档：自动战斗等高频场景使用，切场景/登出仍须 await sync_to_cloud。
func queue_progress_sync() -> void:
	request_background_sync()


func handle_conflict(parent: Node, _conflict_result: Dictionary) -> Dictionary:
	var char_id := NetworkManager.get_character_id()
	if char_id.is_empty():
		return {"ok": false, "resolved": false}

	var dl := await download_for_character(char_id)
	if not dl.get("ok", false):
		_set_status(SyncStatus.CONFLICT, "拉取云端存档失败")
		return dl

	var data: Dictionary = dl.get("data", {})
	apply_server_save(data.get("save", {}), int(data.get("saveVersion", 0)))
	await _prompt_relogin_after_conflict(parent)
	return {
		"ok": false,
		"resolved": true,
		"relogin": true,
		"source": "server",
		"message": "请重新登录",
	}


func _prompt_relogin_after_conflict(parent: Node) -> void:
	var host := parent if parent != null and is_instance_valid(parent) else get_tree().root
	SaveManager.session_active = false
	Game.auto_battle = false
	_set_status(SyncStatus.OFFLINE, "请重新登录")
	var dialog := AcceptDialog.new()
	dialog.title = "存档冲突"
	dialog.dialog_text = "云端存档已被其他设备更新，已用云端存档覆盖。\n请重新登录。"
	host.add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()
	NetworkManager.logout()
	get_tree().change_scene_to_file("res://scenes/login/LoginScene.tscn")


func flush_sync_queue(parent: Node = null) -> void:
	if not NetworkManager.logged_in:
		return
	if not has_pending_queue():
		_refresh_status()
		return
	if not ConnectivityMonitor.is_online():
		_set_status(SyncStatus.QUEUED, "离线·连接重试中")
		return

	_set_status(SyncStatus.SYNCING, "重试同步...")
	var result := await sync_to_cloud(parent, parent != null)
	if result.get("ok", false):
		_stop_retry_timer()
	elif int(result.get("code", 0)) != CONFLICT_CODE:
		_schedule_retry()


func _run_background_sync() -> void:
	await sync_to_cloud(null, false)
	_background_running = false


func _on_retry_timer() -> void:
	if not NetworkManager.logged_in or not NetworkManager.has_character():
		_stop_retry_timer()
		return
	if not has_pending_queue() and _current_status != SyncStatus.QUEUED:
		_stop_retry_timer()
		return
	if not ConnectivityMonitor.is_online():
		_set_status(SyncStatus.QUEUED, "离线·连接重试中")
		_schedule_retry()
		return
	if _background_running or _sync_in_flight:
		return
	request_background_sync()


func _schedule_retry() -> void:
	if _retry_timer and _retry_timer.is_stopped():
		_retry_timer.start(_retry_delay)
		_retry_delay = minf(_retry_delay * 2.0, ApiConfig.SYNC_RETRY_MAX_SEC)


func _stop_retry_timer() -> void:
	if _retry_timer and not _retry_timer.is_stopped():
		_retry_timer.stop()
	_reset_retry_delay()


func _refresh_status() -> void:
	if not NetworkManager.logged_in:
		_set_status(SyncStatus.OFFLINE, "未登录")
	elif not ConnectivityMonitor.is_online():
		if has_pending_queue() or _current_status == SyncStatus.QUEUED:
			_set_status(SyncStatus.QUEUED, "离线·连接重试中")
		else:
			_set_status(SyncStatus.OFFLINE, "无法连接服务器")
	elif has_pending_queue():
		_set_status(SyncStatus.QUEUED, "待重试同步")
		_schedule_retry()
	else:
		_set_status(SyncStatus.IDLE, "就绪")


func await_online() -> bool:
	await ConnectivityMonitor.await_ready()
	return ConnectivityMonitor.is_online()


func _set_status(status: int, message: String) -> void:
	_current_status = status
	_current_message = message
	sync_status_changed.emit(status, message)


func _show_toast(parent: Node, message: String) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var dialog := AcceptDialog.new()
	dialog.title = "云同步"
	dialog.dialog_text = message
	parent.add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()


func _enqueue_sync(char_id: String, save_data: Dictionary, save_version: int) -> void:
	var cid := ApiIds.from_value(char_id)
	_sync_queue = _sync_queue.filter(func(e): return ApiIds.from_value(e.get("character_id", "")) != cid)
	_sync_queue.append({
		"character_id": cid,
		"save": save_data,
		"save_version": save_version,
		"queued_at": int(Time.get_unix_time_from_system()),
	})


func _clear_queue_entry(char_id: String) -> void:
	var cid := ApiIds.from_value(char_id)
	_sync_queue = _sync_queue.filter(func(e): return ApiIds.from_value(e.get("character_id", "")) != cid)


func _is_auth_failure(result: Dictionary) -> bool:
	if int(result.get("code", 0)) == ApiConfig.CLIENT_AUTH_EXPIRED_CODE:
		return true
	var status := int(result.get("http_status", 0))
	return status == 401 or status == ApiConfig.HTTP_UNAUTHORIZED
