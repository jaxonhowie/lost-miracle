extends Area2D

var _player_nearby: bool = false
var _hint_label: Label = null
var _shop_panel: PanelContainer = null

func _ready():
	_hint_label = Label.new()
	_hint_label.text = "[E] 打开商店"
	_hint_label.position = Vector2(-50, -60)
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.visible = false
	add_child(_hint_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Find shop panel in UILayer
	await get_tree().process_frame
	var uilayer = get_node_or_null("../UILayer")
	if uilayer:
		_shop_panel = uilayer.get_node_or_null("ShopPanel")

func _on_body_entered(body):
	if body.is_in_group("player"):
		_player_nearby = true
		_hint_label.visible = true
		if _shop_panel:
			_shop_panel.near_merchant = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		_player_nearby = false
		_hint_label.visible = false
		if _shop_panel:
			_shop_panel.near_merchant = false
			if _shop_panel.is_open:
				_shop_panel.toggle()

func _input(event):
	if _player_nearby and event.is_action_pressed("equipment"):
		if _shop_panel and not _shop_panel.is_open:
			_shop_panel.toggle()
