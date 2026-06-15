extends CanvasLayer

## 全局云同步状态角标

@onready var _label: Label = $Margin/Label


func _ready() -> void:
	layer = 100
	_label.add_theme_font_size_override("font_size", 13)
	_update_display(CloudSaveService.get_status(), CloudSaveService.get_status_message())
	CloudSaveService.sync_status_changed.connect(_on_sync_status_changed)
	NetworkManager.loginStateChanged.connect(_on_login_state_changed)


func _on_sync_status_changed(status: int, _message: String) -> void:
	_update_display(status, _message)


func _on_login_state_changed() -> void:
	_update_display(CloudSaveService.get_status(), CloudSaveService.get_status_message())


func _update_display(status: int, _message: String) -> void:
	var text := CloudSaveService.get_status_text()
	match status:
		CloudSaveService.SyncStatus.OFFLINE:
			_label.modulate = Color(0.65, 0.65, 0.7)
		CloudSaveService.SyncStatus.SYNCING:
			_label.modulate = Color(0.75, 0.85, 1.0)
		CloudSaveService.SyncStatus.OK:
			_label.modulate = Color(0.55, 0.9, 0.65)
		CloudSaveService.SyncStatus.CONFLICT:
			_label.modulate = Color(1.0, 0.55, 0.35)
		CloudSaveService.SyncStatus.QUEUED, CloudSaveService.SyncStatus.FAILED:
			_label.modulate = Color(1.0, 0.8, 0.35)
		_:
			_label.modulate = Color(0.8, 0.82, 0.88)
	_label.text = "☁ %s" % text
