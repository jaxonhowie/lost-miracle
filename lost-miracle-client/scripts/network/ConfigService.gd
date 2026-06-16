extends Node

## 运行时配置 — 登录后从服务端拉取 config bundle

signal config_updated(version: int)

var version: int = 0
var _configs: Dictionary = {}

func _ready() -> void:
	NetworkManager.loginStateChanged.connect(_on_login_state_changed)
	if NetworkManager.logged_in:
		call_deferred("_fetch_if_logged_in")

func _fetch_if_logged_in() -> void:
	await fetch_bundle(false)

func _on_login_state_changed() -> void:
	if NetworkManager.logged_in:
		await fetch_bundle(false)

func fetch_bundle(force: bool = false) -> bool:
	if not NetworkManager.logged_in:
		return false
	var path := "/config/bundle"
	if version > 0 and not force:
		path += "?since=%d" % version
	var result = await NetworkManager.api_request("GET", path)
	if not result.get("ok", false):
		push_warning("ConfigService: fetch failed: %s" % result.get("message", ""))
		return false
	var data: Dictionary = result.get("data", {})
	var server_version := int(data.get("version", 0))
	if bool(data.get("unchanged", false)):
		version = server_version
		return true
	var configs: Dictionary = data.get("configs", {})
	if configs.is_empty() and server_version <= version:
		return true
	_apply_bundle(server_version, configs)
	return true

func _apply_bundle(new_version: int, configs: Dictionary) -> void:
	version = new_version
	for key in configs:
		_configs[key] = configs[key]
	DataManager.apply_runtime_config(_configs)
	config_updated.emit(version)

func get_config(key: String, fallback: Variant = null) -> Variant:
	return _configs.get(key, fallback)

func get_loot_table(key: String, monster_type: String, fallback: Dictionary) -> Dictionary:
	var table: Variant = get_config(key, null)
	if table is Dictionary and table.has(monster_type):
		var row = table[monster_type]
		if row is Dictionary:
			return row
	return fallback
