extends Control

@onready var continue_btn: Button = $VBox/ContinueBtn
@onready var new_game_btn: Button = $VBox/NewGameBtn
@onready var quit_btn: Button = $VBox/QuitBtn
@onready var confirm_panel: PanelContainer = $ConfirmPanel
@onready var confirm_label: Label = $ConfirmPanel/VBox/Label
@onready var confirm_yes: Button = $ConfirmPanel/VBox/HBox/YesBtn
@onready var confirm_no: Button = $ConfirmPanel/VBox/HBox/NoBtn

var _pending_action: String = ""

func _ready():
	confirm_panel.visible = false
	var has_save = FileAccess.file_exists("user://save.json")
	continue_btn.disabled = not has_save
	continue_btn.pressed.connect(_on_continue)
	new_game_btn.pressed.connect(_on_new_game)
	quit_btn.pressed.connect(_on_quit)
	confirm_yes.pressed.connect(_on_confirm_yes)
	confirm_no.pressed.connect(_on_confirm_no)

func _on_continue():
	get_tree().change_scene_to_file("res://scenes/maps/DungeonFloor1.tscn")

func _on_new_game():
	if FileAccess.file_exists("user://save.json"):
		_pending_action = "new_game"
		confirm_label.text = "已有存档，开始新游戏将覆盖存档。\n确定继续？"
		confirm_panel.visible = true
	else:
		_start_new_game()

func _on_quit():
	get_tree().quit()

func _start_new_game():
	DirAccess.remove_absolute("user://save.json")
	get_tree().change_scene_to_file("res://scenes/maps/DungeonFloor1.tscn")

func _on_confirm_yes():
	confirm_panel.visible = false
	match _pending_action:
		"new_game":
			_start_new_game()
		"quit":
			get_tree().quit()
	_pending_action = ""

func _on_confirm_no():
	confirm_panel.visible = false
	_pending_action = ""

func _input(event):
	if event.is_action_pressed("ui_accept") and not confirm_panel.visible:
		if not continue_btn.disabled:
			_on_continue()
