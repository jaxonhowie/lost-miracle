extends CanvasLayer

var is_paused: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	$Panel.visible = false
	$Panel/VBox/ContinueBtn.pressed.connect(_on_continue_pressed)
	$Panel/VBox/MenuBtn.pressed.connect(_on_menu_pressed)
	$Panel/VBox/QuitBtn.pressed.connect(_on_quit_pressed)

func _input(event):
	if event.is_action_pressed("pause"):
		if is_paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _pause():
	is_paused = true
	get_tree().paused = true
	$Panel.visible = true
	_close_all_panels()

func _resume():
	is_paused = false
	get_tree().paused = false
	$Panel.visible = false

func _close_all_panels():
	var panels = ["InventoryPanel", "EquipmentPanel", "EnhancePanel", "ShopPanel"]
	for panel_name in panels:
		var ui_layer = get_node_or_null("../UILayer")
		if not ui_layer:
			continue
		var panel = ui_layer.get_node_or_null(panel_name)
		if panel and panel.has_method("toggle") and panel.is_open:
			panel.toggle()

func _on_continue_pressed():
	_resume()

func _on_menu_pressed():
	_resume()
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")

func _on_quit_pressed():
	get_tree().quit()
