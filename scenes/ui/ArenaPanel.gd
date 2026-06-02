extends PanelContainer

var is_open: bool = false
var pvp_sys: Node

var _current_opponent: Dictionary = {}

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var opponent_panel: VBoxContainer = $VBoxContainer/OpponentPanel
@onready var opp_name_label: Label = $VBoxContainer/OpponentPanel/OppNameLabel
@onready var opp_info_label: Label = $VBoxContainer/OpponentPanel/OppInfoLabel
@onready var match_btn: Button = $VBoxContainer/MatchButton
@onready var fight_btn: Button = $VBoxContainer/FightButton
@onready var result_label: Label = $VBoxContainer/ResultLabel

func _ready():
	visible = false
	pvp_sys = get_node_or_null("/root/PvPSystem")
	if pvp_sys:
		pvp_sys.match_found.connect(_on_match_found)
		pvp_sys.battle_result.connect(_on_battle_result)

	match_btn.pressed.connect(_on_match_pressed)
	fight_btn.pressed.connect(_on_fight_pressed)
	fight_btn.disabled = true
	opponent_panel.visible = false

func toggle():
	is_open = !is_open
	visible = is_open
	if is_open:
		_refresh()

func _refresh():
	if not pvp_sys:
		return
	if pvp_sys.is_matching:
		status_label.text = "匹配中..."
		match_btn.disabled = true
	else:
		status_label.text = "准备就绪"
		match_btn.disabled = false

func _on_match_pressed():
	if not pvp_sys:
		return
	pvp_sys.start_matchmaking()
	status_label.text = "匹配中..."
	match_btn.disabled = true
	opponent_panel.visible = false
	fight_btn.disabled = true
	result_label.text = ""

func _on_match_found(opponent: Dictionary):
	_current_opponent = opponent
	status_label.text = "找到对手!"
	opponent_panel.visible = true
	opp_name_label.text = opponent["name"]
	opp_info_label.text = "Lv.%d %s | 荣誉: %d" % [
		opponent["level"],
		_get_class_name(opponent["class"]),
		opponent["honor"]
	]
	fight_btn.disabled = false
	match_btn.disabled = false

func _on_fight_pressed():
	if _current_opponent.is_empty() or not pvp_sys:
		return
	fight_btn.disabled = true
	status_label.text = "战斗中..."
	var result = pvp_sys.resolve_battle(_current_opponent)
	# Result handled by signal

func _on_battle_result(won: bool, opponent: Dictionary, honor_change: int):
	if won:
		result_label.text = "胜利! 荣誉 %+d" % honor_change
		result_label.modulate = Color(0.3, 1.0, 0.3)
		AudioManager.play_sfx("res://assets/audio/sfx_enhance_success.ogg")
	else:
		result_label.text = "战败... 荣誉 %d" % honor_change
		result_label.modulate = Color(1.0, 0.3, 0.3)
		AudioManager.play_sfx("res://assets/audio/sfx_enhance_fail.ogg")
	status_label.text = "战斗结束"
	_current_opponent = {}
	opponent_panel.visible = false

	await get_tree().create_timer(3.0).timeout
	result_label.modulate = Color.WHITE
	match_btn.disabled = false

func _get_class_name(class_id: String) -> String:
	match class_id:
		"warrior": return "战士"
		"ranger": return "弓箭手"
		"assassin": return "刺客"
		"mage": return "法师"
		"elven": return "精灵召唤师"
	return class_id
