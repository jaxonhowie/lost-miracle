extends Node

## 云存档同步：上传/下载、冲突处理、失败重试队列、状态广播

const CONFLICT_CODE := 40901
const SYNC_QUEUE_PATH := "user://sync_queue.json"
const RETRY_INTERVAL_SEC := 5.0

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


func _ready() -> void:
	_retry_timer = Timer.new()
	_retry_timer.wait_time = RETRY_INTERVAL_SEC
	_retry_timer.autostart = false
	_retry_timer.timeout.connect(_on_retry_timer)
	add_child(_retry_timer)
	NetworkManager.loginStateChanged.connect(_on_login_state_changed)
	_refresh_offline_or_idle_status()
	call_deferred("try_resume_sync")


func _on_login_state_changed() -> void:
	_refresh_offline_or_idle_status()
	if NetworkManager.logged_in:
		call_deferred("try_resume_sync")
	else:
		_stop_retry_timer()


func get_status() -> int:
	return _current_status


func get_status_message() -> String:
	return _current_message


func get_status_text() -> String:
	match _current_status:
		SyncStatus.OFFLINE:
			return "仅本地存档"
		SyncStatus.SYNCING:
			return "云同步中..."
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
		and not NetworkManager.get_character_id().is_empty()
		and not SaveManager.current_save_id.is_empty()
	)


func has_pending_queue() -> bool:
	return not _load_queue().is_empty()


func clear_pending_sync(char_id: String) -> void:
	_clear_queue_entry(char_id)


func try_resume_sync() -> void:
	if not can_sync():
		return
	if not has_pending_queue() and _current_status != SyncStatus.QUEUED:
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
	SaveManager.save_game()
	_clear_queue_entry(NetworkManager.get_character_id())
	_stop_retry_timer()
	_set_status(SyncStatus.OK, "已同步")


func bind_cloud_character(char_meta: Dictionary, cloud_save: Dictionary, save_version: int) -> String:
	var char_id := ApiIds.from_value(char_meta.get("id", char_meta.get("character_id", "")))
	var save_id := SaveManager.find_local_save_id_for_character(char_id)
	if save_id.is_empty():
		save_id = SaveManager.create_cache_for_character(char_id, char_meta, cloud_save)
	else:
		SaveManager.current_save_id = save_id
		SaveManager.import_save_data(cloud_save)
		SaveManager.update_manifest_for_character(char_id, char_meta)
		SaveManager.save_game()
	NetworkManager.set_character_id(char_id)
	NetworkManager.set_save_version(save_version)
	_clear_queue_entry(char_id)
	_stop_retry_timer()
	_set_status(SyncStatus.OK, "已同步")
	return save_id


func sync_current() -> Dictionary:
	if not NetworkManager.logged_in:
		return {"ok": false, "code": -1, "message": "未登录"}
	var char_id := NetworkManager.get_character_id()
	if char_id.is_empty() or SaveManager.current_save_id.is_empty():
		return {"ok": false, "code": -1, "message": "未选择角色"}
	var save_data := SaveManager.export_save_data()
	var result := await upload_for_character(char_id, save_data, NetworkManager.get_save_version())
	if result.get("ok", false):
		NetworkManager.set_save_version(int(result["data"].get("saveVersion", NetworkManager.get_save_version())))
		_clear_queue_entry(char_id)
		sync_completed.emit(true, "同步成功")
		return result
	if int(result.get("code", 0)) == CONFLICT_CODE:
		sync_completed.emit(false, "存档版本冲突")
		return result
	_enqueue_sync(char_id, save_data, NetworkManager.get_save_version())
	sync_completed.emit(false, str(result.get("message", "同步失败")))
	return result


func sync_after_local_save(parent: Node = null, interact_on_conflict: bool = true) -> Dictionary:
	if not can_sync():
		_set_status(SyncStatus.OFFLINE, "仅本地存档")
		return {"ok": true, "skipped": true, "message": "仅本地存档"}

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
		if parent and interact_on_conflict:
			var resolved := await handle_conflict(parent, result)
			if resolved.get("ok", false):
				_set_status(SyncStatus.OK, "冲突已解决")
				return resolved
			if resolved.get("cancelled", false):
				_set_status(SyncStatus.CONFLICT, "同步冲突未解决")
				return {"ok": false, "cancelled": true, "code": CONFLICT_CODE, "message": "已取消冲突处理"}
			_set_status(SyncStatus.CONFLICT, "冲突处理失败")
			return resolved
		_set_status(SyncStatus.CONFLICT, "存档冲突，待处理")
		return result

	_set_status(SyncStatus.QUEUED, "同步失败，已加入重试队列")
	_schedule_retry()
	return result


func sync_before_scene_exit(parent: Node) -> Dictionary:
	SaveManager.save_game()
	var result := await sync_after_local_save(parent, true)
	if result.get("cancelled", false):
		_show_toast(parent, "请先解决存档冲突后再离开")
	return result


func request_background_sync() -> void:
	if _background_running:
		return
	_background_running = true
	_run_background_sync()


func resolve_conflict_interactive(parent: Node, _conflict_data: Dictionary) -> String:
	var dialog := ConfirmationDialog.new()
	dialog.title = "存档冲突"
	dialog.dialog_text = "云端存档已被其他设备更新。\n请选择要保留的版本："
	dialog.ok_button_text = "以云端为准"
	dialog.cancel_button_text = "取消"
	parent.add_child(dialog)

	var choice := {"value": "cancel"}
	dialog.confirmed.connect(func():
		choice.value = "server"
		dialog.hide()
	)
	dialog.canceled.connect(func():
		choice.value = "cancel"
		dialog.hide()
	)

	var local_btn := Button.new()
	local_btn.text = "以本地为准"
	local_btn.pressed.connect(func():
		choice.value = "local"
		dialog.hide()
	)
	if dialog.get_child_count() > 0:
		var margin = dialog.get_child(0)
		if margin is MarginContainer:
			var vb = margin.get_child(0)
			if vb is VBoxContainer:
				vb.add_child(local_btn)

	dialog.popup_centered(Vector2(400, 180))
	while dialog.visible:
		await parent.get_tree().process_frame
	dialog.queue_free()
	return str(choice.value)


func handle_conflict(parent: Node, conflict_result: Dictionary) -> Dictionary:
	var char_id := NetworkManager.get_character_id()
	if char_id.is_empty():
		return {"ok": false, "resolved": false}

	var choice := await resolve_conflict_interactive(parent, conflict_result.get("data", {}))
	if choice == "cancel":
		return {"ok": false, "resolved": false, "cancelled": true}

	if choice == "server":
		var dl := await download_for_character(char_id)
		if not dl.get("ok", false):
			return dl
		var data: Dictionary = dl.get("data", {})
		apply_server_save(data.get("save", {}), int(data.get("saveVersion", 0)))
		return {"ok": true, "resolved": true, "source": "server"}

	var save_data := SaveManager.export_save_data()
	var up := await upload_for_character(char_id, save_data, NetworkManager.get_save_version(), true)
	if up.get("ok", false):
		NetworkManager.set_save_version(int(up["data"].get("saveVersion", NetworkManager.get_save_version())))
		_clear_queue_entry(char_id)
	return up


func flush_sync_queue(parent: Node = null) -> void:
	if not NetworkManager.logged_in:
		return
	if not has_pending_queue():
		_refresh_offline_or_idle_status()
		return

	_set_status(SyncStatus.SYNCING, "重试同步...")
	var result := await sync_after_local_save(parent, parent != null)
	if result.get("ok", false):
		_stop_retry_timer()
	elif int(result.get("code", 0)) != CONFLICT_CODE:
		_schedule_retry()


func _run_background_sync() -> void:
	await sync_after_local_save(null, false)
	_background_running = false


func _on_retry_timer() -> void:
	if not can_sync():
		_stop_retry_timer()
		return
	if not has_pending_queue() and _current_status != SyncStatus.QUEUED:
		_stop_retry_timer()
		return
	if _background_running or _sync_in_flight:
		return
	request_background_sync()


func _schedule_retry() -> void:
	if _retry_timer and _retry_timer.is_stopped():
		_retry_timer.start()


func _stop_retry_timer() -> void:
	if _retry_timer and not _retry_timer.is_stopped():
		_retry_timer.stop()


func _refresh_offline_or_idle_status() -> void:
	if not NetworkManager.logged_in:
		_set_status(SyncStatus.OFFLINE, "仅本地存档")
	elif has_pending_queue():
		_set_status(SyncStatus.QUEUED, "待重试同步")
		_schedule_retry()
	else:
		_set_status(SyncStatus.IDLE, "就绪")


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
	var queue := _load_queue()
	queue = queue.filter(func(e): return ApiIds.from_value(e.get("character_id", "")) != cid)
	queue.append({
		"character_id": cid,
		"save": save_data,
		"save_version": save_version,
		"queued_at": int(Time.get_unix_time_from_system()),
	})
	_write_queue(queue)


func _clear_queue_entry(char_id: String) -> void:
	var cid := ApiIds.from_value(char_id)
	var queue := _load_queue()
	queue = queue.filter(func(e): return ApiIds.from_value(e.get("character_id", "")) != cid)
	_write_queue(queue)


func _load_queue() -> Array:
	if not FileAccess.file_exists(SYNC_QUEUE_PATH):
		return []
	var file = FileAccess.open(SYNC_QUEUE_PATH, FileAccess.READ)
	if not file:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return []
	file.close()
	if json.data is Array:
		return json.data
	return []


func _write_queue(queue: Array) -> void:
	var file = FileAccess.open(SYNC_QUEUE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(queue, "\t"))
		file.close()
