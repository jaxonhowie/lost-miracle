extends Node

## 网络可达性探活：定期请求服务端健康端点，维护在线状态并在恢复时通知。
## 这是当前 HTTP 短连接架构下实现"断连自动重连后立即推送"体验的核心。

signal connectivity_changed(online: bool)
signal online_restored

var online: bool = false
## 首次探活是否已完成（启动后需要等它，避免在状态未知时盲目发请求）。
var first_probe_done: bool = false

var _probing: bool = false
var _offline_interval: float = 0.0
var _timer: Timer


func _ready() -> void:
	_offline_interval = ApiConfig.PROBE_INTERVAL_OFFLINE_INIT
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	# 启动后立即探活一次，尽快确定初始在线状态。
	_probe()


func is_online() -> bool:
	return online


## 等待首次探活完成。调用方在依赖在线状态前可先 await。
func await_ready() -> void:
	while not first_probe_done:
		await get_tree().create_timer(0.1).timeout


func _on_timer() -> void:
	_probe()


func _probe() -> void:
	if _probing:
		return
	_probing = true

	var http := HTTPRequest.new()
	http.timeout = 5
	add_child(http)

	var ok := await _perform_probe(http)
	http.queue_free()
	_apply_result(ok)


func _perform_probe(http: HTTPRequest) -> bool:
	var url := "%s%s" % [ApiConfig.BASE_URL, ApiConfig.HEALTH_PATH]
	var err := http.request(url, PackedStringArray(), HTTPClient.METHOD_GET, "")
	if err != OK:
		return false
	var result: Array = await http.request_completed
	var result_code: int = result[0]
	var status: int = result[1]
	return result_code == HTTPRequest.RESULT_SUCCESS and status == 200


func _apply_result(ok: bool) -> void:
	_probing = false
	_schedule_next(ok)

	if not first_probe_done:
		# 首次探活：无论结果都确立初始状态。
		first_probe_done = true
		online = ok
		connectivity_changed.emit(online)
		if online:
			online_restored.emit()
		return

	if ok == online:
		return

	# 状态发生翻转
	var was_online := online
	online = ok
	if not was_online and online:
		# offline -> online：恢复，立即通知订阅者冲刺队列。
		online_restored.emit()
	connectivity_changed.emit(online)


func _schedule_next(online_now: bool) -> void:
	if online_now:
		_timer.start(ApiConfig.PROBE_INTERVAL_ONLINE)
		# 恢复在线后重置离线退避基线，下次断连从初始间隔重新增长。
		_offline_interval = ApiConfig.PROBE_INTERVAL_OFFLINE_INIT
	else:
		# 离线时指数退避，尽快发现恢复。
		_timer.start(_offline_interval)
		_offline_interval = minf(_offline_interval * 2.0, ApiConfig.PROBE_INTERVAL_OFFLINE_MAX)
