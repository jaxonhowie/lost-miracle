extends Control

@onready var continue_btn: Button = $VBox/ContinueBtn
@onready var new_game_btn: Button = $VBox/NewGameBtn
@onready var settings_btn: Button = $VBox/SettingsBtn
@onready var quit_btn: Button = $VBox/QuitBtn
@onready var confirm_panel: PanelContainer = $ConfirmPanel
@onready var confirm_label: Label = $ConfirmPanel/VBox/Label
@onready var confirm_yes: Button = $ConfirmPanel/VBox/HBox/YesBtn
@onready var confirm_no: Button = $ConfirmPanel/VBox/HBox/NoBtn
@onready var slot_selector: PanelContainer = $SaveSlotSelector
@onready var settings_panel: CanvasLayer = $SettingsPanel

var _pending_action: String = ""

func _ready():
	confirm_panel.visible = false
	slot_selector.visible = false
	var save_sys = get_node_or_null("/root/SaveSystem")
	var has_any_save = false
	if save_sys:
		has_any_save = save_sys.has_slot(1) or save_sys.has_slot(2) or save_sys.has_slot(3)
	continue_btn.disabled = not has_any_save
	continue_btn.pressed.connect(_on_continue)
	new_game_btn.pressed.connect(_on_new_game)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	confirm_yes.pressed.connect(_on_confirm_yes)
	confirm_no.pressed.connect(_on_confirm_no)

func _on_continue():
	slot_selector.show_mode("load")

func _on_new_game():
	slot_selector.show_mode("new")

func _on_settings():
	settings_panel.toggle()

func _on_quit():
	get_tree().quit()

func _on_confirm_yes():
	confirm_panel.visible = false
	match _pending_action:
		"quit":
			get_tree().quit()
	_pending_action = ""

func _on_confirm_no():
	confirm_panel.visible = false
	_pending_action = ""

func _input(event):
	if slot_selector.visible or settings_panel.get_node("Panel").visible or confirm_panel.visible:
		return
	if event.is_action_pressed("ui_accept"):
		if not continue_btn.disabled:
			_on_continue()
